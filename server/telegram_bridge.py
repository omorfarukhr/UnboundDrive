import os
import io
import json
import asyncio
from aiohttp import web
from telethon import TelegramClient, errors
from telethon.tl.functions.channels import CreateChannelRequest, GetFullChannelRequest
from telethon.tl.types import InputPeerChannel

# Telegram API credentials (official desktop client fallback or .env)
API_ID = int(os.environ.get("TELEGRAM_API_ID", "2040"))
API_HASH = os.environ.get("TELEGRAM_API_HASH", "b18441a1ff607e10a989891a5462e627")

# Active clients map: phone -> {"client": TelegramClient, "phone_code_hash": str, "vault_channel_id": int}
active_clients = {}

# Active concurrency limiter: max 8 concurrent MTProto file uploads to prevent rate limit starvation
UPLOAD_SEMAPHORE = asyncio.Semaphore(8)

def get_cors_headers():
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Phone, X-Chunk-Index",
    }

async def handle_options(request):
    return web.Response(headers=get_cors_headers())

def get_client_for_request(request):
    phone = request.headers.get("X-Phone", "").strip()
    if not phone and len(active_clients) == 1:
        # Fallback to single active user session
        phone = list(active_clients.keys())[0]
    
    if phone and phone in active_clients:
        return phone, active_clients[phone]["client"]
    return None, None

async def handle_send_code(request):
    try:
        data = await request.json()
        phone = data.get("phone_number", "").strip()
        if not phone:
            return web.json_response({"status": "error", "message": "Phone number is required"}, status=400, headers=get_cors_headers())

        os.makedirs("server", exist_ok=True)
        session_name = f"session_{abs(hash(phone))}"
        client = TelegramClient(os.path.join("server", session_name), API_ID, API_HASH)
        await client.connect()

        result = await client.send_code_request(phone)
        active_clients[phone] = {
            "client": client,
            "phone_code_hash": result.phone_code_hash,
            "vault_channel_id": None,
        }

        print(f"[Telegram Bridge] Code sent successfully to {phone} (Hash: {result.phone_code_hash})")
        return web.json_response({
            "status": "ok",
            "phone_code_hash": result.phone_code_hash,
        }, headers=get_cors_headers())
    except errors.PhoneNumberInvalidError:
        return web.json_response({"status": "error", "message": "Invalid phone number."}, status=400, headers=get_cors_headers())
    except errors.FloodWaitError as e:
        return web.json_response({"status": "error", "message": f"Telegram rate limit: Wait {e.seconds} seconds."}, status=429, headers=get_cors_headers())
    except Exception as e:
        print(f"[Error send_code] {e}")
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

async def handle_verify_code(request):
    try:
        data = await request.json()
        phone = data.get("phone_number", "").strip()
        code = data.get("code", "").strip()
        phone_code_hash = data.get("phone_code_hash", "").strip()

        client_entry = active_clients.get(phone)
        if not client_entry:
            session_name = f"session_{abs(hash(phone))}"
            client = TelegramClient(os.path.join("server", session_name), API_ID, API_HASH)
            await client.connect()
            client_entry = {"client": client, "phone_code_hash": phone_code_hash, "vault_channel_id": None}
            active_clients[phone] = client_entry
        else:
            client = client_entry["client"]
            if not phone_code_hash:
                phone_code_hash = client_entry.get("phone_code_hash")

        try:
            user = await client.sign_in(phone=phone, code=code, phone_code_hash=phone_code_hash)
            print(f"[Telegram Bridge] Authenticated successfully as {user.first_name} ({user.id})")
            
            # Ensure vault channel is provisioned
            channel_id = await ensure_vault_channel(client)
            client_entry["vault_channel_id"] = channel_id

            return web.json_response({
                "status": "authenticated",
                "user": {
                    "id": user.id,
                    "first_name": user.first_name or "",
                    "username": user.username or "",
                    "phone": phone,
                    "vault_channel_id": channel_id,
                }
            }, headers=get_cors_headers())
        except errors.SessionPasswordNeededError:
            print(f"[Telegram Bridge] 2FA Password needed for {phone}")
            return web.json_response({"status": "2fa_required"}, headers=get_cors_headers())
        except errors.PhoneCodeInvalidError:
            return web.json_response({"status": "error", "message": "Invalid verification code."}, status=400, headers=get_cors_headers())
        except errors.PhoneCodeExpiredError:
            return web.json_response({"status": "error", "message": "Verification code has expired. Request a new one."}, status=400, headers=get_cors_headers())
    except Exception as e:
        print(f"[Error verify_code] {e}")
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

async def handle_verify_2fa(request):
    try:
        data = await request.json()
        phone = data.get("phone_number", "").strip()
        password = data.get("password", "")

        client_entry = active_clients.get(phone)
        if not client_entry:
            return web.json_response({"status": "error", "message": "Session expired. Please restart login."}, status=400, headers=get_cors_headers())

        client = client_entry["client"]
        user = await client.sign_in(password=password)
        print(f"[Telegram Bridge] 2FA Authenticated successfully as {user.first_name}")

        channel_id = await ensure_vault_channel(client)
        client_entry["vault_channel_id"] = channel_id

        return web.json_response({
            "status": "authenticated",
            "user": {
                "id": user.id,
                "first_name": user.first_name or "",
                "vault_channel_id": channel_id,
            }
        }, headers=get_cors_headers())
    except errors.PasswordHashInvalidError:
        return web.json_response({"status": "error", "message": "Incorrect 2FA password."}, status=400, headers=get_cors_headers())
    except Exception as e:
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

async def ensure_vault_channel(client):
    """Finds existing UnboundDrive Vault channel or creates a new strictly private channel."""
    try:
        async for dialog in client.iter_dialogs(limit=50):
            if dialog.is_channel and "UnboundDrive Personal Vault" in dialog.name:
                return dialog.id

        # Not found, create private storage channel
        created = await client(CreateChannelRequest(
            title="UnboundDrive Personal Vault",
            about="Strictly Private Zero-Knowledge Vault Storage for UnboundDrive. Do not delete.",
            megagroup=False,
        ))
        channel = created.chats[0]
        print(f"[Telegram Bridge] Created private vault channel: {channel.id}")
        return channel.id
    except Exception as e:
        print(f"[Telegram Bridge] Notice finding/creating channel: {e}")
        return None

async def handle_upload_chunk(request):
    """Scalable chunk upload endpoint with concurrency control and FloodWait protection."""
    phone, client = get_client_for_request(request)
    if not client:
        return web.json_response({"status": "error", "message": "Unauthorized or no active session."}, status=401, headers=get_cors_headers())

    try:
        chunk_bytes = await request.read()
        if not chunk_bytes:
            return web.json_response({"status": "error", "message": "Empty chunk payload."}, status=400, headers=get_cors_headers())

        channel_id = active_clients.get(phone, {}).get("vault_channel_id")
        if not channel_id:
            channel_id = await ensure_vault_channel(client)
            if phone in active_clients:
                active_clients[phone]["vault_channel_id"] = channel_id

        # Load balancing concurrency control
        async with UPLOAD_SEMAPHORE:
            chunk_file = io.BytesIO(chunk_bytes)
            chunk_file.name = f"chunk_{len(chunk_bytes)}.ubd"

            message = await client.send_file(
                channel_id or "me",
                file=chunk_file,
                caption="#unbound_chunk",
                force_document=True,
            )

            return web.json_response({
                "status": "ok",
                "telegram_message_id": message.id,
                "size": len(chunk_bytes),
            }, headers=get_cors_headers())

    except errors.FloodWaitError as e:
        print(f"[FloodWait] Telegram rate limit active: wait {e.seconds} seconds")
        return web.json_response({
            "status": "error",
            "message": f"Telegram rate limit: Wait {e.seconds} seconds.",
            "wait_seconds": e.seconds,
        }, status=429, headers=get_cors_headers())
    except Exception as e:
        print(f"[Error upload_chunk] {e}")
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

async def handle_download_chunk(request):
    """Streams an encrypted chunk from Telegram by message ID."""
    phone, client = get_client_for_request(request)
    if not client:
        return web.json_response({"status": "error", "message": "Unauthorized."}, status=401, headers=get_cors_headers())

    msg_id = request.query.get("message_id")
    if not msg_id:
        return web.json_response({"status": "error", "message": "message_id is required."}, status=400, headers=get_cors_headers())

    try:
        channel_id = active_clients.get(phone, {}).get("vault_channel_id") or "me"
        message = await client.get_messages(channel_id, ids=int(msg_id))
        if not message or not message.media:
            return web.json_response({"status": "error", "message": "Chunk message not found."}, status=404, headers=get_cors_headers())

        buffer = io.BytesIO()
        await client.download_media(message, file=buffer)
        buffer.seek(0)

        response = web.Response(
            body=buffer.read(),
            content_type="application/octet-stream",
            headers=get_cors_headers(),
        )
        return response
    except errors.FloodWaitError as e:
        return web.json_response({
            "status": "error",
            "message": f"Telegram rate limit: Wait {e.seconds} seconds.",
            "wait_seconds": e.seconds,
        }, status=429, headers=get_cors_headers())
    except Exception as e:
        print(f"[Error download_chunk] {e}")
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

async def handle_sync_manifest(request):
    """Pins encrypted vault ledger in user's vault channel."""
    phone, client = get_client_for_request(request)
    if not client:
        return web.json_response({"status": "error", "message": "Unauthorized."}, status=401, headers=get_cors_headers())

    try:
        manifest_bytes = await request.read()
        channel_id = active_clients.get(phone, {}).get("vault_channel_id") or "me"

        file_obj = io.BytesIO(manifest_bytes)
        file_obj.name = "vault_ledger.ubd"

        msg = await client.send_file(
            channel_id,
            file=file_obj,
            caption="#unbound_manifest_v1",
            force_document=True,
        )
        # Pin the latest ledger message for instant discovery
        try:
            await client.pin_message(channel_id, msg.id, notify=False)
        except Exception:
            pass

        return web.json_response({"status": "ok", "message_id": msg.id}, headers=get_cors_headers())
    except Exception as e:
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

async def handle_get_manifest(request):
    """Retrieves the latest encrypted vault ledger."""
    phone, client = get_client_for_request(request)
    if not client:
        return web.json_response({"status": "error", "message": "Unauthorized."}, status=401, headers=get_cors_headers())

    try:
        channel_id = active_clients.get(phone, {}).get("vault_channel_id") or "me"
        messages = await client.get_messages(channel_id, limit=20, search="#unbound_manifest_v1")
        if not messages:
            return web.json_response({"status": "not_found"}, status=404, headers=get_cors_headers())

        latest_msg = messages[0]
        buffer = io.BytesIO()
        await client.download_media(latest_msg, file=buffer)
        buffer.seek(0)

        return web.Response(
            body=buffer.read(),
            content_type="application/octet-stream",
            headers=get_cors_headers(),
        )
    except Exception as e:
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

app = web.Application(client_max_size=1024 * 1024 * 100) # 100MB per chunk limit
app.router.add_route("OPTIONS", "/{tail:.*}", handle_options)
app.router.add_post("/api/auth/send_code", handle_send_code)
app.router.add_post("/api/auth/verify_code", handle_verify_code)
app.router.add_post("/api/auth/verify_2fa", handle_verify_2fa)
app.router.add_post("/api/drive/upload_chunk", handle_upload_chunk)
app.router.add_get("/api/drive/download_chunk", handle_download_chunk)
app.router.add_post("/api/drive/sync_manifest", handle_sync_manifest)
app.router.add_get("/api/drive/get_manifest", handle_get_manifest)

if __name__ == "__main__":
    print("==================================================")
    print("  [+] UnboundDrive Scalable MTProto Bridge v2.0  ")
    print("  [*] Multi-Stream Chunk Pool & Fault Tolerance   ")
    print("  [*] Listening on http://localhost:8086          ")
    print("==================================================")
    web.run_app(app, host="127.0.0.1", port=8086)
