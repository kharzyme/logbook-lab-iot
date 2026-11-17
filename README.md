# Logbook Lab IoT — Decentralized Borrowing Logbook (dApp)

Aplikasi mobile berbasis **Flutter** dan **Ethereum Smart Contract (Solidity)** untuk pencatatan peminjaman dan pengembalian inventaris perangkat IoT secara transparan, anti-manipulasi (*immutable*), dan terdesentralisasi pada jaringan uji coba **Ethereum Sepolia Testnet**.

---

## Fitur Utama & Fungsionalitas

1. **Integrasi Dompet Web3 (Reown AppKit / WalletConnect v2):**
   - Menghubungkan aplikasi mobile langsung ke **MetaMask Mobile** pada jaringan **Sepolia Testnet (Chain ID: 11155111)**.
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

## Arsitektur & Teknologi

| Komponen | Teknologi / Pustaka | Keterangan |
| :--- | :--- | :--- |
| **Smart Contract** | Solidity (`^0.8.20`) | Kontrak `LogbookLabV2` di jaringan Sepolia |
| **Mobile Frontend** | Flutter (Dart) | Antarmuka mobile Android (`minSdk 23`, `compileSdk 35`) |
| **Web3 Client** | `web3dart` | Interaksi baca/tulis fungsi dan *event listener* ABI |
| **Wallet Connector** | `reown_appkit` | Protokol WalletConnect v2 untuk MetaMask Mobile |
| **Node Provider** | Alchemy RPC | Koneksi JSON-RPC & WebSocket ke Ethereum Sepolia |

---

## Informasi Smart Contract

- **Nama Kontrak:** `LogbookLabV2`
- **Jaringan:** Ethereum Sepolia Testnet (`Chain ID: 11155111`)
- **Alamat Kontrak:** `0x491200928E1Eb29cd056a981eFd9b6f7C2e59BC2`
- **Explorer:** [Lihat di Sepolia Etherscan](https://sepolia.etherscan.io/address/0x491200928E1Eb29cd056a981eFd9b6f7C2e59BC2)

---

## Struktur Proyek

```text
blockchain_app/
├── assets/
│   └── abi/
│       └── LogbookLabV2.json     # Application Binary Interface (ABI) Smart Contract
├── lib/
│   ├── config/
│   │   └── app_config.dart       # Konfigurasi alamat kontrak, Chain ID, & environment
│   ├── services/
│   │   └── blockchain_service.dart # Layanan komunikasi web3dart & event listener
│   └── main.dart                 # Antarmuka utama (UI), manajemen state, & Reown AppKit
└── pubspec.yaml                  # Daftar dependensi Flutter