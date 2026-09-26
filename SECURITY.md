# 🛡️ UnboundDrive Security Architecture & Threat Model

> **Principle: "Don't Store What You Cannot Protect."**  
> UnboundDrive is engineered so that even if the developer's infrastructure is seized, Telegram's servers are fully compromised, or the network traffic is intercepted by state actors, **user data remains mathematically impossible to decrypt.**

---

## 🏛️ 1. Zero-Central-Database Architecture (Eliminating Data Breaches)

Traditional cloud storage services (Dropbox, Google Drive, Box) store user metadata, folder hierarchies, and file indices in centralized databases (PostgreSQL, MongoDB, MySQL). When a single database credentials leak occurs, millions of users' personal photos, tax records, and documents are dumped onto black markets.

### The UnboundDrive Antidote:
1. **NO Central Server Database:** UnboundDrive operates with **zero central databases**.
2. **Encrypted Vault Manifest (`SecureVaultManifest`):** The entire database of a user's drive exists exclusively as a single, tamper-evident binary envelope (`.ubd`).
3. **Storage Location:** The encrypted manifest is stored locally within the smartphone's sandboxed storage and mirrored as an encrypted blob in the user's private Telegram channel.
4. **Result:** There is **no database on any server to breach, steal, or sell on the dark web**.

---

## 🔐 2. Memory-Hard Key Derivation (Argon2id)

Weak key derivation functions (MD5, plain SHA-256, low-iteration PBKDF2) allow adversaries using GPU or ASIC cracking clusters to test billions of password guesses per second.

* **Algorithm:** `Argon2id` (compliant with RFC 9106, winner of the Password Hashing Competition).
* **Memory-Hardness:** Demands up to **64 MB of RAM** per hash computation.
* **Why it matters:** Unlike CPUs and GPUs which excel at register-based computation, forcing massive parallel RAM allocation starves GPU memory buses, making brute-force password cracking economically and physically unfeasible.

---

## 🔑 3. Hardware-Backed Keystore & Secure Enclave

* **Android:** Keys are generated and sealed using the `Android Keystore Provider` backed by hardware-isolated TEE (Trusted Execution Environment) or Google Titan M security chips.
* **iOS:** Keys reside within the Apple `Secure Enclave` processor.
* **Memory Zeroization:** Sensitive cryptographic byte arrays are actively zeroed out in RAM upon completion using `HardwareSecurityManager.zeroizeMemory()` to neutralize physical memory dump attacks (cold-boot attacks).

---

## 📦 4. Binary Envelope Specification (`.ubd`)

Every file uploaded to Telegram's cloud is wrapped into an **UnboundDrive Authenticated Envelope**:

```
+---------------+----------------+----------------------+--------------------+
| Magic: 'UBD1' | IV (16 Bytes)  | HMAC-SHA256 (32 B)   | Ciphertext Payload |
+---------------+----------------+----------------------+--------------------+
```

1. **Metadata Blinding:** Original filename, extension, file size, and timestamps are encrypted *inside* the payload. To Telegram's data centers, the file is an unrecognizable binary file named `f_<hash>.ubd`.
2. **Encrypt-then-MAC (EtM):** Tampering with even a single bit of the file in the cloud invalidates the constant-time HMAC check, causing the decryption routine to reject the file immediately.

---

## 📋 5. Threat Model (STRIDE Assessment)

| Threat | Risk in Traditional Cloud | UnboundDrive Mitigation |
| :--- | :--- | :--- |
| **Spoofing** | Attacker impersonates service | MTProto cryptographic handshake + Telegram 2FA |
| **Tampering** | Cloud provider modifies files | Authenticated Encryption (HMAC-SHA256 verification) |
| **Repudiation** | Denying file modification | Cryptographic manifest versioning with sequential timestamps |
| **Information Disclosure** | Database breach sold on dark web | **Zero-Central-Database**: No server database exists |
| **Denial of Service** | Storage limits enforced / Account lock | Distributed Telegram Multi-DC infrastructure |
| **Elevation of Privilege** | Server admin reads user files | Zero-Knowledge client encryption; admin holds zero keys |

---

## 🚨 Responsible Disclosure

If you discover a security vulnerability within UnboundDrive, please report it privately via GitHub Security Advisories or email `security@unbounddrive.app`. We acknowledge and credit all valid security research.
