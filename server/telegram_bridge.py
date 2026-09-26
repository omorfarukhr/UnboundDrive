import os
import re
import io
import json
import asyncio
from aiohttp import web
from telethon import TelegramClient, errors
from telethon.tl.functions.channels import CreateChannelRequest

# Telegram API credentials (official desktop client fallback or .env)
API_ID = int(os.environ.get("TELEGRAM_API_ID", "2040"))
API_HASH = os.environ.get("TELEGRAM_API_HASH", "b18441a1ff607e10a989891a5462e627")

# Active clients map: clean_phone -> {"client": TelegramClient, "phone_code_hash": str, "vault_channel_id": int}
active_clients = {}

# Active concurrency limiter: max 8 concurrent MTProto file uploads to prevent rate limit starvation
UPLOAD_SEMAPHORE = asyncio.Semaphore(8)

ACTIVE_HASHES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "active_hashes.json")

def get_saved_hash(phone: str) -> str:
    digits = re.sub(r'\D', '', phone)
    if not os.path.exists(ACTIVE_HASHES_FILE):
        return ""
    try:
        with open(ACTIVE_HASHES_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data.get(digits, "")
    except Exception as e:
        print(f"[Telegram Bridge] get_saved_hash error: {e}", flush=True)
        return ""

def save_hash(phone: str, hash_val: str):
    digits = re.sub(r'\D', '', phone)
    data = {}
    if os.path.exists(ACTIVE_HASHES_FILE):
        try:
            with open(ACTIVE_HASHES_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            data = {}
    data[digits] = hash_val
    try:
        with open(ACTIVE_HASHES_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        print(f"[Telegram Bridge] Saved active hash for {phone}: {hash_val}", flush=True)
    except Exception as e:
        print(f"[Telegram Bridge] Failed to save active hash: {e}", flush=True)

def remove_hash(phone: str):
    digits = re.sub(r'\D', '', phone)
    if os.path.exists(ACTIVE_HASHES_FILE):
        try:
            with open(ACTIVE_HASHES_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            if digits in data:
                del data[digits]
                with open(ACTIVE_HASHES_FILE, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
        except Exception:
            pass

def clean_phone(phone: str) -> str:
    return re.sub(r'[^\d+]', '', phone).strip()

def get_session_name(phone: str) -> str:
    digits = re.sub(r'\D', '', phone)
    return f"session_{digits}"

def get_cors_headers():
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Phone, X-Chunk-Index",
    }

async def handle_options(request):
    return web.Response(headers=get_cors_headers())

def get_or_create_client(phone: str):
    phone = clean_phone(phone)
    if phone in active_clients and active_clients[phone].get("client"):
        return phone, active_clients[phone]["client"]

    os.makedirs("server", exist_ok=True)
    session_file = os.path.join("server", get_session_name(phone))
    client = TelegramClient(
        session_file,
        API_ID,
        API_HASH,
        device_model="UnboundDrive Mobile",
        system_version="Android 14",
        app_version="2.4.0",
        connection_retries=5,
        retry_delay=1,
        auto_reconnect=True,
    )

    if phone not in active_clients:
        active_clients[phone] = {
            "client": client,
            "phone_code_hash": None,
            "vault_channel_id": None,
        }
    else:
        active_clients[phone]["client"] = client

    return phone, client

async def ensure_connected(client: TelegramClient):
    if not client.is_connected():
        await client.connect()

def get_client_for_request(request):
    phone = request.headers.get("X-Phone", "").strip()
    if not phone and len(active_clients) == 1:
        phone = list(active_clients.keys())[0]

    phone = clean_phone(phone)
    if phone and phone in active_clients:
        return phone, active_clients[phone]["client"]
    elif phone:
        return get_or_create_client(phone)
    return None, None

async def handle_send_code(request):
    try:
        data = await request.json()
        raw_phone = data.get("phone_number", "").strip()
        if not raw_phone:
            return web.json_response(
                {"status": "error", "message": "Phone number is required."},
                status=400,
                headers=get_cors_headers(),
            )

        phone, client = get_or_create_client(raw_phone)
        result = None
        last_error = None
        saved_hash = get_saved_hash(phone)

        for attempt in range(3):
            try:
                await ensure_connected(client)
                print(f"[Telegram Bridge] Sending OTP request to {phone} (attempt {attempt+1})...", flush=True)
                result = await client.send_code_request(phone)
                break
            except errors.SendCodeUnavailableError as e:
                print(f"[Telegram Bridge] SendCodeUnavailableError: code already dispatched. Using active hash.", flush=True)
                current_hash = saved_hash or active_clients.get(phone, {}).get("phone_code_hash")
                if current_hash:
                    active_clients[phone]["phone_code_hash"] = current_hash
                    return web.json_response({
                        "status": "ok",
                        "phone_code_hash": current_hash,
                        "message": "Verification code already sent to your Telegram app."
                    }, headers=get_cors_headers())
                last_error = e
                break
            except errors.AuthRestartError as e:
                print(f"[Telegram Bridge] AuthRestartError: {e}", flush=True)
                last_error = e
                await asyncio.sleep(1.0)
                await ensure_connected(client)
            except (ConnectionError, OSError) as e:
                print(f"[Telegram Bridge] Connection error: {e}", flush=True)
                last_error = e
                await asyncio.sleep(1.0)
                await ensure_connected(client)
            except errors.FloodWaitError as e:
                print(f"[Telegram Bridge] FloodWaitError: wait {e.seconds}s", flush=True)
                return web.json_response({
                    "status": "error",
                    "message": f"Telegram rate limit: Wait {e.seconds} seconds before requesting another code.",
                    "wait_seconds": e.seconds
                }, status=429, headers=get_cors_headers())
            except errors.PhoneNumberInvalidError:
                return web.json_response({
                    "status": "error",
                    "message": "Invalid phone number format for Telegram."
                }, status=400, headers=get_cors_headers())
            except Exception as e:
                print(f"[Telegram Bridge] Unexpected send_code error: {type(e)} {e}", flush=True)
                err_str = str(e).lower()
                if "already used" in err_str or "options for this type" in err_str or "sendcodeunavailable" in err_str:
                    current_hash = saved_hash or active_clients.get(phone, {}).get("phone_code_hash")
                    if current_hash:
                        print(f"[Telegram Bridge] Active hash found ({current_hash}), returning ok", flush=True)
                        active_clients[phone]["phone_code_hash"] = current_hash
                        return web.json_response({
                            "status": "ok",
                            "phone_code_hash": current_hash,
                            "message": "Verification code already sent to your Telegram app."
                        }, headers=get_cors_headers())
                last_error = e
                break

        if not result:
            current_hash = saved_hash or active_clients.get(phone, {}).get("phone_code_hash")
            if current_hash:
                print(f"[Telegram Bridge] Fallback to saved hash {current_hash} for {phone}", flush=True)
                active_clients[phone]["phone_code_hash"] = current_hash
                return web.json_response({
                    "status": "ok",
                    "phone_code_hash": current_hash,
                    "message": "Verification code already sent to your Telegram app."
                }, headers=get_cors_headers())

            err_msg = str(last_error) if last_error else "Connection to Telegram timed out. Please tap Continue again."
            return web.json_response(
                {"status": "error", "message": err_msg},
                status=500,
                headers=get_cors_headers(),
            )

        active_clients[phone]["phone_code_hash"] = result.phone_code_hash
        save_hash(phone, result.phone_code_hash)
        print(f"[Telegram Bridge] Real Telegram OTP dispatched to {phone} (Hash: {result.phone_code_hash})")

        return web.json_response({
            "status": "ok",
            "phone_code_hash": result.phone_code_hash,
        }, headers=get_cors_headers())

    except errors.PhoneNumberInvalidError:
        return web.json_response(
            {"status": "error", "message": "Invalid phone number format for Telegram."},
            status=400,
            headers=get_cors_headers(),
        )
    except errors.FloodWaitError as e:
        print(f"[Telegram Bridge] Flood wait: wait {e.seconds} seconds.")
        return web.json_response(
            {"status": "error", "message": f"Telegram rate limit: Wait {e.seconds} seconds.", "wait_seconds": e.seconds},
            status=429,
            headers=get_cors_headers(),
        )
    except Exception as e:
        print(f"[Error send_code] {e}")
        return web.json_response(
            {"status": "error", "message": str(e)},
            status=500,
            headers=get_cors_headers(),
        )

async def handle_verify_code(request):
    try:
        data = await request.json()
        raw_phone = data.get("phone_number", "").strip()
        code = data.get("code", "").strip()
        phone_code_hash = data.get("phone_code_hash", "").strip()

        phone, client = get_or_create_client(raw_phone)
        await ensure_connected(client)

        if not phone_code_hash:
            phone_code_hash = active_clients.get(phone, {}).get("phone_code_hash") or get_saved_hash(phone)

        try:
            user = await client.sign_in(phone=phone, code=code, phone_code_hash=phone_code_hash)
            print(f"[Telegram Bridge] Authenticated successfully as {user.first_name} ({user.id})")
            remove_hash(phone)

            channel_id = await ensure_vault_channel(client)
            active_clients[phone]["vault_channel_id"] = channel_id

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
            return web.json_response(
                {"status": "error", "message": "Invalid verification code."},
                status=400,
                headers=get_cors_headers(),
            )
        except errors.PhoneCodeExpiredError:
            remove_hash(phone)
            return web.json_response(
                {"status": "error", "message": "Verification code expired. Please request a new one."},
                status=400,
                headers=get_cors_headers(),
            )
    except Exception as e:
        print(f"[Error verify_code] {e}")
        return web.json_response(
            {"status": "error", "message": str(e)},
            status=500,
            headers=get_cors_headers(),
        )

async def handle_verify_2fa(request):
    try:
        data = await request.json()
        raw_phone = data.get("phone_number", "").strip()
        password = data.get("password", "")

        phone, client = get_or_create_client(raw_phone)
        await ensure_connected(client)

        user = await client.sign_in(password=password)
        print(f"[Telegram Bridge] 2FA Authenticated successfully as {user.first_name}")

        channel_id = await ensure_vault_channel(client)
        active_clients[phone]["vault_channel_id"] = channel_id

        return web.json_response({
            "status": "authenticated",
            "user": {
                "id": user.id,
                "first_name": user.first_name or "",
                "vault_channel_id": channel_id,
            }
        }, headers=get_cors_headers())
    except errors.PasswordHashInvalidError:
        return web.json_response(
            {"status": "error", "message": "Incorrect 2FA password."},
            status=400,
            headers=get_cors_headers(),
        )
    except Exception as e:
        return web.json_response(
            {"status": "error", "message": str(e)},
            status=500,
            headers=get_cors_headers(),
        )

async def ensure_vault_channel(client):
    """Finds existing UnboundDrive Vault channel or creates a new strictly private channel."""
    try:
        await ensure_connected(client)
        async for dialog in client.iter_dialogs(limit=50):
            if dialog.is_channel and "UnboundDrive Personal Vault" in dialog.name:
                return dialog.id

        created = await client(CreateChannelRequest(
            title="UnboundDrive Personal Vault",
            about="Strictly Private Zero-Knowledge Vault Storage for UnboundDrive. Do not delete.",
            megagroup=False,
        ))
        channel = created.chats[0]
        print(f"[Telegram Bridge] Created private vault channel: {channel.id}")
        return channel.id
    except Exception as e:
        print(f"[Telegram Bridge] Vault channel notice: {e}")
        return None

async def handle_upload_chunk(request):
    phone, client = get_client_for_request(request)
    if not client:
        return web.json_response({"status": "error", "message": "Unauthorized."}, status=401, headers=get_cors_headers())

    try:
        chunk_bytes = await request.read()
        if not chunk_bytes:
            return web.json_response({"status": "error", "message": "Empty chunk payload."}, status=400, headers=get_cors_headers())

        await ensure_connected(client)
        channel_id = active_clients.get(phone, {}).get("vault_channel_id")
        if not channel_id:
            channel_id = await ensure_vault_channel(client)
            if phone in active_clients:
                active_clients[phone]["vault_channel_id"] = channel_id

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
        return web.json_response({
            "status": "error",
            "message": f"Telegram rate limit: Wait {e.seconds} seconds.",
            "wait_seconds": e.seconds,
        }, status=429, headers=get_cors_headers())
    except Exception as e:
        print(f"[Error upload_chunk] {e}")
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

async def handle_download_chunk(request):
    phone, client = get_client_for_request(request)
    if not client:
        return web.json_response({"status": "error", "message": "Unauthorized."}, status=401, headers=get_cors_headers())

    msg_id = request.query.get("message_id")
    if not msg_id:
        return web.json_response({"status": "error", "message": "message_id is required."}, status=400, headers=get_cors_headers())

    try:
        await ensure_connected(client)
        channel_id = active_clients.get(phone, {}).get("vault_channel_id") or "me"
        message = await client.get_messages(channel_id, ids=int(msg_id))
        if not message or not message.media:
            return web.json_response({"status": "error", "message": "Chunk message not found."}, status=404, headers=get_cors_headers())

        buffer = io.BytesIO()
        await client.download_media(message, file=buffer)
        buffer.seek(0)

        return web.Response(
            body=buffer.read(),
            content_type="application/octet-stream",
            headers=get_cors_headers(),
        )
    except errors.FloodWaitError as e:
        return web.json_response({
            "status": "error",
            "message": f"Telegram rate limit: Wait {e.seconds} seconds.",
            "wait_seconds": e.seconds,
        }, status=429, headers=get_cors_headers())
    except Exception as e:
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

async def handle_sync_manifest(request):
    phone, client = get_client_for_request(request)
    if not client:
        return web.json_response({"status": "error", "message": "Unauthorized."}, status=401, headers=get_cors_headers())

    try:
        manifest_bytes = await request.read()
        await ensure_connected(client)
        channel_id = active_clients.get(phone, {}).get("vault_channel_id") or "me"

        file_obj = io.BytesIO(manifest_bytes)
        file_obj.name = "vault_ledger.ubd"

        msg = await client.send_file(
            channel_id,
            file=file_obj,
            caption="#unbound_manifest_v1",
            force_document=True,
        )
        try:
            await client.pin_message(channel_id, msg.id, notify=False)
        except Exception:
            pass

        return web.json_response({"status": "ok", "message_id": msg.id}, headers=get_cors_headers())
    except Exception as e:
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

async def handle_get_manifest(request):
    phone, client = get_client_for_request(request)
    if not client:
        return web.json_response({"status": "error", "message": "Unauthorized."}, status=401, headers=get_cors_headers())

    try:
        await ensure_connected(client)
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

app = web.Application(client_max_size=1024 * 1024 * 100)
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
    print("  [+] UnboundDrive Scalable MTProto Bridge v2.4  ")
    print("  [*] Auto-Reconnect & Fault-Tolerant Session     ")
    print("  [*] Listening on http://localhost:8086          ")
    print("==================================================")
    web.run_app(app, host="127.0.0.1", port=8086)
