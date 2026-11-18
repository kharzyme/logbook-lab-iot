// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LogbookLabV2 {
    struct Peminjaman {
        string namaAlat;
        address peminjam;
        uint256 waktuPinjam;
        uint256 waktuKembali; // 0 = masih dipinjam
        bool dihapus;
    }

    Peminjaman[] private daftar;
    mapping(bytes32 => bool) public sedangDipinjam;

    event AlatDipinjam(uint256 indexed id, string namaAlat, address indexed peminjam, uint256 waktuPinjam);
    event AlatDikembalikan(uint256 indexed id, string namaAlat, uint256 waktuKembali);
    event AlatDiedit(uint256 indexed id, string namaAlatBaru);
    event CatatanDihapus(uint256 indexed id);

    function _kunciAlat(string memory namaAlat) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(namaAlat));
    }

    function pinjamAlat(string calldata namaAlat) external {
        require(bytes(namaAlat).length > 0, "Nama alat tidak boleh kosong");
        bytes32 kunci = _kunciAlat(namaAlat);
        require(!sedangDipinjam[kunci], "Alat ini sedang dipinjam oleh akun lain!");

        sedangDipinjam[kunci] = true;
        daftar.push(Peminjaman(namaAlat, msg.sender, block.timestamp, 0, false));
        emit AlatDipinjam(daftar.length - 1, namaAlat, msg.sender, block.timestamp);
    }

    function kembalikanAlat(uint256 id) external {
        require(id < daftar.length, "Data tidak ditemukan");
        require(!daftar[id].dihapus, "Catatan sudah dihapus");
        require(daftar[id].peminjam == msg.sender, "Hanya peminjam asli yang bisa mengembalikan");
        require(daftar[id].waktuKembali == 0, "Alat sudah dikembalikan");

        daftar[id].waktuKembali = block.timestamp;
        sedangDipinjam[_kunciAlat(daftar[id].namaAlat)] = false;
        emit AlatDikembalikan(id, daftar[id].namaAlat, block.timestamp);
    }

    function editNamaAlat(uint256 id, string calldata namaBaru) external {
        require(id < daftar.length, "Data tidak ditemukan");
        require(!daftar[id].dihapus, "Catatan sudah dihapus");
        require(daftar[id].peminjam == msg.sender, "Bukan peminjam alat ini");
        require(daftar[id].waktuKembali == 0, "Alat sudah dikembalikan, tidak bisa diedit");
        require(bytes(namaBaru).length > 0, "Nama baru tidak boleh kosong");

        bytes32 kunciBaru = _kunciAlat(namaBaru);
        require(!sedangDipinjam[kunciBaru], "Nama alat baru sedang dipinjam akun lain");

        sedangDipinjam[_kunciAlat(daftar[id].namaAlat)] = false;
        sedangDipinjam[kunciBaru] = true;
        daftar[id].namaAlat = namaBaru;

        emit AlatDiedit(id, namaBaru);
    }

    function hapusCatatan(uint256 id) external {
        require(id < daftar.length, "Data tidak ditemukan");
        require(daftar[id].peminjam == msg.sender, "Bukan pemilik catatan");
        require(daftar[id].waktuKembali != 0, "Kembalikan alat dulu sebelum menghapus");
        require(!daftar[id].dihapus, "Sudah dihapus");

        daftar[id].dihapus = true;
        emit CatatanDihapus(id);
    }

    function jumlahPeminjaman() external view returns (uint256) {
        return daftar.length;
    }

    function ambilPeminjaman(uint256 id) external view returns (
        string memory namaAlat,
        address peminjam,
        uint256 waktuPinjam,
        uint256 waktuKembali,
        bool dihapus
    ) {
        require(id < daftar.length, "Data tidak ditemukan");
        Peminjaman storage p = daftar[id];
        return (p.namaAlat, p.peminjam, p.waktuPinjam, p.waktuKembali, p.dihapus);
    }
}