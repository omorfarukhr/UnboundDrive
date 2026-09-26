# 🚀 UnboundDrive

> **Storage without limits. Break free from 15GB.**  
> A sleek, privacy-focused, cross-platform mobile cloud drive that transforms Telegram's infinite cloud infrastructure into your personal, subscription-free Google Drive & Google Photos alternative.

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue.svg)](https://flutter.dev)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter%203-02569B?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Storage](https://img.shields.io/badge/Storage-Unlimited%20%E2%88%9E-purple.svg)](#)
[![Encryption](https://img.shields.io/badge/Security-Client--Side%20AES--256-orange.svg)](#)

---

## 🌟 Why UnboundDrive?

Tired of getting that annoying notification: *"Your Google storage is 90% full. Upgrade to Google One for $2.99/mo"*? 

Traditional cloud storage providers trap you in recurring monthly fees while locking your personal memories behind arbitrary caps. **UnboundDrive** leverages Telegram's globally distributed, high-speed, and free cloud storage infrastructure to give you a true **personal cloud drive with zero subscriptions**.

---

## ✨ Key Features

- ☁️ **Infinite Cloud Storage:** No 15GB limits. No monthly subscriptions. Store photos, 4K videos, documents, and backups forever.
- 📸 **Smart Auto-Backup:** Runs quietly in the background like Google Photos. Automatically backs up new camera shots and videos when connected to Wi-Fi.
- ⚡ **Turbo Multi-Stream Transfers:** Maximum bandwidth utilization with multi-part parallel uploads and resumable downloads.
- 🔗 **Direct Browser & IDM Sharing:** Generate direct streaming links so anyone can view or download your files with 1 click without needing Telegram or logging in.
- 🔒 **Zero-Knowledge Security (AES-256):** Optional client-side military-grade encryption. Your files are encrypted on your device *before* reaching the cloud—even Telegram cannot read them.
- 🗂️ **Google Drive-Class Organization:** Clean folder trees, instant search, grid/list toggle, and in-app media preview (Photos, Videos, PDFs).
- 🧩 **2GB+ Auto-Chunking:** Seamlessly splits large files (>2GB) during upload and reassembles them automatically on download.

---

## 🏗️ System Architecture

```mermaid
flowchart TD
    User["📱 UnboundDrive Mobile App (Flutter)"]
    
    subgraph CoreEngine ["⚡ Core Client Layer"]
        Riverpod["State Management (Riverpod)"]
        LocalDB["Local Metadata Cache (Hive/SQLite)"]
        AutoSync["Background Auto-Backup (WorkManager)"]
        Crypto["AES-256-GCM Client Encryption"]
    end
    
    subgraph TelegramEngine ["📡 Telegram Cloud Engine"]
        TDLib["TDLib (Telegram Database Library)"]
        MTProto["MTProto Protocol"]
    end
    
    subgraph Cloud ["☁️ Telegram Distributed Storage"]
        PrivateChannel["User's Private Vault Channel"]
        GlobalDC["Global Telegram Data Centers"]
    end

    User --> Riverpod
    Riverpod --> LocalDB
    Riverpod --> AutoSync
    Riverpod --> Crypto
    Crypto --> TDLib
    TDLib --> MTProto
    MTProto --> PrivateChannel
    PrivateChannel --> GlobalDC
```

---

## 🔒 Military-Grade Zero-Knowledge Cryptography

Security in UnboundDrive is **mathematically unbreakable** by design. Your master key never touches Telegram or any third-party server.

* **Key Derivation (KDF):** `PBKDF2-HMAC-SHA512` with **100,000+ rounds** and a 32-byte cryptographically secure random salt.
* **Authenticated Encryption (EtM):** `AES-256` in CBC mode paired with an authenticating `HMAC-SHA256` digest (Encrypt-then-MAC).
* **Metadata Blinding:** Filenames, extensions, file sizes, and directory trees are 100% encrypted inside binary `.ubd` envelopes. Telegram's servers only see opaque binary blobs with no identifying info.
* **Constant-Time Verification:** Signature comparison uses constant-time byte algorithms to neutralize timing side-channel attacks.

---

## 🔌 Embedded Systems & Hardware Integration

UnboundDrive isn't just a mobile app—it is an ecosystem that bridges **low-cost embedded hardware with infinite cloud storage**.

* 📦 **UnboundBox (Home NAS Gateway):** Run our lightweight embedded daemon on a **Raspberry Pi** (Zero/3/4/5) or Orange Pi to expose an encrypted local network drive (Samba/WebDAV) that streams files directly into your Telegram vault.
* 📹 **UnboundCam (IoT Surveillance Hub):** Stream motion-triggered video from **ESP32-CAM** microcontrollers directly to the cloud for free infinite security archives.
* 🔑 **Hardware Token Security:** Support for physical USB/NFC hardware keys (YubiKey / ESP32 hardware dongles) to store your master decryption key offline.

👉 *See the full [Embedded Documentation & Gateway Guide](embedded/README.md).*

---

## 📂 Project Structure

```
unbounddrive/
├── embedded/              # Raspberry Pi / Embedded Linux & IoT gateway
│   ├── README.md          # Hardware guide
│   └── unbound_box_gateway.py
├── android/               # Native Android configuration
├── ios/                   # Native iOS configuration
├── lib/
│   ├── app/               # App configuration, themes, routing
│   ├── core/              # Security (AES-256-EtM), utils, constants
│   └── features/          # Feature modules (auth, drive, backup, transfers)
├── pubspec.yaml           # Dependencies and assets
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.19+)
- Dart SDK (v3.3+)
- Android Studio / Xcode
- Telegram API Credentials ([my.telegram.org](https://my.telegram.org)):
  - `API_ID`
  - `API_HASH`

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/unbounddrive.git
   cd unbounddrive
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment:**
   Create a `.env` file in the root directory:
   ```env
   TELEGRAM_API_ID=your_api_id_here
   TELEGRAM_API_HASH=your_api_hash_here
   ```

4. **Run the App:**
   ```bash
   flutter run
   ```

---

## 🔒 Privacy & Legal Notice

UnboundDrive is an independent client that uses the official Telegram API in compliance with Telegram's API Terms of Service. UnboundDrive is not affiliated with, endorsed, or sponsored by Telegram FZ-LLC. Your data is stored directly in your personal Telegram private cloud.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
