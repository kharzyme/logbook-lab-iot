# Logbook Lab IoT — Decentralized Borrowing Logbook (dApp)

Aplikasi mobile berbasis **Flutter** dan **Ethereum Smart Contract (Solidity)** untuk pencatatan peminjaman dan pengembalian inventaris perangkat IoT secara transparan, anti-manipulasi (*immutable*), dan terdesentralisasi pada jaringan uji coba **Ethereum Sepolia Testnet**.

---

## Fitur Utama & Fungsionalitas

1. **Integrasi Dompet Web3 (Reown AppKit / WalletConnect v2):**
   - Menghubungkan aplikasi mobile langsung ke **MetaMask Mobile** pada jaringan **Sepolia Testnet (Chain ID: 11155111)** tanpa menyimpan *private key* di dalam aplikasi.
   - Menampilkan alamat wallet aktif dan total catatan transaksi yang tersimpan di blockchain.
2. **Pencatatan Peminjaman On-Chain (`pinjamAlat`):**
   - Menyimpan nama alat, alamat peminjam (`msg.sender`), serta timestamp peminjaman (`block.timestamp`) ke jaringan blockchain.
   - **Validasi Anti-Pinjam Ganda:** Smart contract otomatis menolak transaksi jika perangkat dengan nama yang sama masih berstatus dipinjam.
3. **Pengembalian Perangkat (`kembalikanAlat`):**
   - Hanya peminjam sah (`msg.sender == peminjam`) yang dapat mengembalikan perangkat dan mencatat waktu pengembalian.
4. **Fitur Tambahan (Bonus):**
   - **Edit Nama Alat (`editNamaAlat`):** Memperbarui nama perangkat selama status peminjaman masih aktif oleh peminjam asli.
   - **Filter Status Real-Time:** Menyaring daftar riwayat berdasarkan kategori **Semua**, **Dipinjam**, **Selesai**, dan **Milik Saya**.
   - **Hapus Riwayat (`hapusRiwayat`):** Menghapus entri yang statusnya sudah selesai oleh peminjam terkait.
   - **Sinkronisasi Event Real-Time:** Mendengarkan pancaran *event* dari smart contract untuk memperbarui tampilan secara otomatis.

---

## Arsitektur, Teknologi & Versi Paket

- **Lingkungan Pengembangan:**
  - **Solidity Compiler:** `^0.8.20` (dikompilasi menggunakan `v0.8.34+commit.80d5c536`)
  - **Flutter SDK & Dart:** Kompatibel dengan Android (`minSdk 23`, `compileSdk 35`)
  - **Node Provider:** Alchemy JSON-RPC & WebSocket (Ethereum Sepolia)
- **Versi Paket Utama (`pubspec.yaml`):**
  - `web3dart`: `^2.7.3`
  - `reown_appkit`: `^1.7.6`
  - `flutter_dotenv`: `^6.0.2`
  - `http`: `^1.6.0`

---

## Informasi Smart Contract

- **Nama Kontrak:** `LogbookLabV2`
- **Jaringan:** Ethereum Sepolia Testnet (`Chain ID: 11155111`)
- **Alamat Kontrak:** `0x491200928E1Eb29cd056a981eFd9b6f7C2e59BC2`
- **Explorer (Verified Source Code):** [Lihat di Sepolia Etherscan](https://sepolia.etherscan.io/address/0x491200928E1Eb29cd056a981eFd9b6f7C2e59BC2)

---

## Struktur Proyek

```text
blockchain_app/
├── assets/
│   └── abi/
│       └── LogbookLabV2.json     # Application Binary Interface (ABI) Smart Contract
├── contracts/
│   └── LogbookLabV2.sol          # Kode sumber Smart Contract Solidity (Verified)
├── lib/
│   ├── config/
│   │   └── app_config.dart       # Konfigurasi alamat kontrak, Chain ID, & environment
│   ├── services/
│   │   └── blockchain_service.dart # Layanan komunikasi web3dart & event listener
│   └── main.dart                 # Antarmuka utama (UI), manajemen state, & Reown AppKit
└── pubspec.yaml                  # Daftar dependensi Flutter
```

---

## Cara Menjalankan Proyek (Lokal)

1. **Clone repositori ini:**
   ```bash
   git clone https://github.com/kharzyme/logbook-lab-iot.git
   cd logbook-lab-iot
   ```
2. **Konfigurasi Variabel Lingkungan (`.env`):**
   Buat file baru bernama `.env` di direktori utama proyek (sejajar dengan `pubspec.yaml`), lalu isi konfigurasi berikut:
   ```env
   CONTRACT_ADDRESS=0x491200928E1Eb29cd056a981eFd9b6f7C2e59BC2
   RPC_URL=https://eth-sepolia.g.alchemy.com/v2/MASUKKAN_API_KEY_ALCHEMY_ANDA
   CHAIN_ID=11155111
   REOWN_PROJECT_ID=MASUKKAN_PROJECT_ID_REOWN_ANDA
   ```
3. **Instal dependensi Flutter:**
   ```bash
   flutter pub get
   ```
4. **Jalankan aplikasi pada perangkat Android atau build APK:**
   ```bash
   flutter run --release
   # Atau untuk menghasilkan berkas instalasi APK:
   flutter build apk --release
   ```

---

## Referensi & Sumber Adaptasi

- **Dokumentasi Resmi `web3dart` (pub.dev):** Referensi pemanggilan fungsi *read/write* smart contract dan *event streaming* ABI di Dart.
- **Dokumentasi Resmi Reown AppKit (WalletConnect v2):** Referensi konfigurasi sesi koneksi dompet eksternal (*deep linking* ke MetaMask Mobile) pada jaringan EVM Testnet.
- **Solidity Documentation:** Referensi struktur data `struct`, `mapping`, dan validasi `require` untuk pencegahan peminjaman ganda *on-chain*.
- **Asistensi AI (Gemini):** Digunakan sebagai asisten *debugging* integrasi paket Flutter-Android dan penyusunan struktur dokumentasi proyek.