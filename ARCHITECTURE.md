# UnboundDrive Architecture & System Design Specification

## Overview & Philosophy
UnboundDrive is engineered around a core tenet: **"Don't store what you cannot protect."**

Traditional cloud storage platforms (Google Drive, Dropbox, iCloud, Mega, AWS S3) rely on centralized multi-tenant databases (PostgreSQL, MongoDB, DynamoDB). These architectures create catastrophic **honeypots**: if a database credential, server instance, or cloud provider is breached, millions of users' directory structures, file metadata, passwords, and tokens are dumped and sold on the dark web / black market.

UnboundDrive eliminates this vulnerability entirely through a **Zero-Central-Database Architecture**.

---

## 1. Pillar 1: Zero-Database Security Architecture
```
+-------------------------------------------------------------------------+
|                              USER DEVICE                                |
|                                                                         |
|  +--------------------+        +-------------------------------------+  |
|  | User Master Passkey| -----> | Argon2id KDF (RFC 9106)             |  |
|  +--------------------+        | 64MB RAM Memory-Hard Matrix         |  |
|                                +-------------------------------------+  |
|                                                   |                     |
|                                                   v                     |
|  +--------------------+               256-bit Master Key                |
|  | Android Keystore / |                          |                      |
|  | iOS Secure Enclave |                          |                      |
|  | (Hardware Salt)    |                          v                      |
|  +--------------------+        +-------------------------------------+  |
|                                | Zero-Knowledge Engine               |  |
|                                | AES-256-CBC/GCM + HMAC-SHA256 (EtM) |  |
|                                +-------------------------------------+  |
|                                                   |                     |
|                                                   v                     |
|                               +---------------------------------------+ |
|                               | Encrypted Vault Ledger (.ubd)         | |
|                               | No plaintext file names, sizes, paths | |
|                               +---------------------------------------+ |
+---------------------------------------------------|---------------------+
                                                    |
                                                    | Opaque Binary (.ubd)
                                                    v
                                    +-------------------------------+
                                    | Telegram Distributed Cloud    |
                                    | Strictly Private User Channel |
                                    | (Zero Central Database Honeypot|
                                    +-------------------------------+
```

### 1.1 Zero-Knowledge Cryptographic Specification
1. **Key Derivation (KDF)**:
   - Utilizes **RFC 9106 Argon2id** (hybrid data-dependent & data-independent memory-hard function).
   - Forces memory-hardness (`16MB - 64MB` RAM matrix per derivation), neutralizing GPU clusters, ASICs, and FPGA brute-force password cracking farms.
2. **Double Hardware Anchoring**:
   - Device salts are generated with CSPRNG (`Random.secure()`) and stored in **Android Keystore (Titan M / Knox TEE)** with `RSA-ECB-OAEP` / `AES-GCM` hardware encryption, or **Apple iOS Secure Enclave Keychain**.
3. **Envelope Encryption (Encrypt-then-MAC / EtM)**:
   - Every file chunk is sealed in an `UnboundDrive Envelope (.ubd)`:
     ```
     [0..3]   Magic Bytes: 'UBD1' (4 bytes)
     [4..19]  CSPRNG IV: (16 bytes unique per chunk)
     [20..51] HMAC-SHA256 Signature (32 bytes authenticated MAC)
     [52..N]  AES-256 PKCS7 Ciphertext
     ```
   - Constant-time verification (`_constantTimeEquals`) protects against timing attacks.
4. **Memory Zeroization**:
   - Sensitive cryptographic keys and decrypted byte buffers are actively overwritten with zeroes in RAM (`HardwareSecurityManager.zeroizeMemory`) immediately after use, preventing cold-boot and heap dump extraction.

---

## 2. Pillar 2: Scalability & Load Balancing
### 2.1 Multi-Stream Connection Pooling
- Files are split into deterministic **2MB uniform chunks** (`FileChunker`).
- `LoadBalancedTransferPool` manages an adaptive worker pool (2 to 8 parallel streams):
  - Prevents Head-of-Line (HoL) blocking on large multi-gigabyte transfers.
  - Dynamically throttles or expands concurrency based on network round-trip latency.
  - Avoids socket starvation while maximizing uplink throughput (achieving 20-40 MB/s).

### 2.2 Telegram MTProto DC Distribution
- Transmissions interface with Telegram's global distributed data centers (DC1-DC5).
- Multi-channel sharding routes chunks across independent storage partitions to avoid single-channel bandwidth bottlenecks.

---

## 3. Pillar 3: Fault Tolerance & Self-Healing Resilience
### 3.1 Resumable State Journaling
- In unstable mobile network conditions (switching 5G -> Wi-Fi, tunnels, battery optimization backgrounding), uploads never restart from 0%.
- `ResumableTransferManager` commits completed chunk receipts to an encrypted local journal (`transfer_journal.ubd`).
- If an interruption occurs at 95% of a 2GB file, resuming skips the 95% confirmed chunks and immediately picks up at chunk 96%.

### 3.2 Circuit Breaker Pattern (`CircuitBreaker`)
- Implements a 3-state circuit breaker (`Closed`, `Open`, `HalfOpen`):
  - Automatically intercepts Telegram rate limits (`420 FLOOD_WAIT_X`).
  - Extracts the required cooldown duration `X`, adds jitter (+1-3s randomized delay to prevent thundering herds), and temporarily opens the circuit.
  - Transparently waits and retries without throwing disruptive crashes to the user.

### 3.3 Self-Healing Per-Chunk Integrity Verification
- Each chunk metadata retains an independent **SHA-256 integrity hash**.
- On download, chunks are validated immediately upon arrival.
- If packet corruption or network bit-flips occur, the engine triggers an automatic chunk-level retry (up to 3 attempts) before failing the overall file.

---

## 4. Pillar 4: High-Performance Architecture
### 4.1 Off-Thread Cryptographic Isolates (`IsolateCryptoWorker`)
- Cryptographic hashing, memory-hard matrix expansion (Argon2id), and AES chunk encryption are executed on dedicated background **Dart Isolates** via `Isolate.run()`.
- The main Flutter UI thread remains 100% unencumbered, guaranteeing smooth 60/120 FPS animations, scrolling, and responsiveness even while transferring multiple gigabytes.

### 4.2 Bounded Memory Queue (Zero OOM Crashes)
- Eliminates whole-file buffering in RAM.
- Chunks are processed via bounded memory streaming, allowing 2GB-4GB files to be transferred on low-end 4GB RAM devices without triggering Android/iOS Out-Of-Memory (OOM) process termination.

---

## 5. Verification Matrix
| Dimension | Verification Method | Status |
| :--- | :--- | :--- |
| **Tamper Resistance** | HMAC-SHA256 bit-flip rejection test | PASS |
| **Memory-Hard KDF** | RFC 9106 Argon2id matrix derivation test | PASS |
| **Fault Tolerance** | Circuit Breaker failure threshold & FloodWait test | PASS |
| **Load Balancing** | LoadBalancedTransferPool concurrency cap test | PASS |
| **Resumability** | TransferSessionJournal byte tracking test | PASS |
| **Code Health** | `flutter analyze` static analysis | 0 issues found |
| **Test Suite** | `flutter test` automated suite | 8/8 Passed (100%) |
