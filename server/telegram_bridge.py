import os
import json
import asyncio
from aiohttp import web
from telethon import TelegramClient, errors
from telethon.tl.functions.channels import CreateChannelRequest

# Telegram API credentials (official desktop client fallback or .env)
API_ID = int(os.environ.get("TELEGRAM_API_ID", "2040"))
API_HASH = os.environ.get("TELEGRAM_API_HASH", "b18441a1ff607e10a989891a5462e627")

# Active clients map: phone -> TelegramClient
active_clients = {}

def get_cors_headers():
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
    }

async def handle_options(request):
    return web.Response(headers=get_cors_headers())

async def handle_send_code(request):
    try:
        data = await request.json()
        phone = data.get("phone_number", "").strip()
        if not phone:
            return web.json_response({"status": "error", "message": "Phone number is required"}, status=400, headers=get_cors_headers())

        session_name = f"session_{abs(hash(phone))}"
        client = TelegramClient(os.path.join("server", session_name), API_ID, API_HASH)
        await client.connect()

        result = await client.send_code_request(phone)
        active_clients[phone] = {
            "client": client,
            "phone_code_hash": result.phone_code_hash,
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
        else:
            client = client_entry["client"]
            if not phone_code_hash:
                phone_code_hash = client_entry["phone_code_hash"]

        try:
            user = await client.sign_in(phone=phone, code=code, phone_code_hash=phone_code_hash)
            print(f"[Telegram Bridge] Authenticated successfully as {user.first_name} ({user.id})")
            return web.json_response({
                "status": "authenticated",
                "user": {
                    "id": user.id,
                    "first_name": user.first_name or "",
                    "username": user.username or "",
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
        return web.json_response({
            "status": "authenticated",
            "user": {
                "id": user.id,
                "first_name": user.first_name or "",
            }
        }, headers=get_cors_headers())
    except errors.PasswordHashInvalidError:
        return web.json_response({"status": "error", "message": "Incorrect 2FA password."}, status=400, headers=get_cors_headers())
    except Exception as e:
        return web.json_response({"status": "error", "message": str(e)}, status=500, headers=get_cors_headers())

app = web.Application()
app.router.add_route("OPTIONS", "/{tail:.*}", handle_options)
app.router.add_post("/api/auth/send_code", handle_send_code)
app.router.add_post("/api/auth/verify_code", handle_verify_code)
app.router.add_post("/api/auth/verify_2fa", handle_verify_2fa)

if __name__ == "__main__":
    print("==================================================")
    print("  [+] UnboundDrive Live MTProto Bridge Online     ")
    print("  [*] Connecting to Telegram Production Core      ")
    print("  [*] Listening on http://localhost:8086          ")
    print("==================================================")
    web.run_app(app, host="127.0.0.1", port=8086)
