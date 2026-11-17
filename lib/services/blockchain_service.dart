import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import '../config/app_config.dart';

class PeminjamanItem {
  final int id;
  final String namaAlat;
  final String peminjam;
  final DateTime waktuPinjam;
  final DateTime? waktuKembali;
  final bool dihapus;

  PeminjamanItem({
    required this.id,
    required this.namaAlat,
    required this.peminjam,
    required this.waktuPinjam,
    this.waktuKembali,
    required this.dihapus,
  });

  bool get sudahKembali => waktuKembali != null;
}

class BlockchainService {
  late final Web3Client _client;
  late DeployedContract _contract;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _client = Web3Client(AppConfig.rpcUrl, Client());
    final abiString = await rootBundle.loadString(AppConfig.abiAssetPath);
    final contractAddr = EthereumAddress.fromHex(AppConfig.contractAddress);
    _contract = DeployedContract(
      ContractAbi.fromJson(abiString, 'LogbookLabV2'),
      contractAddr,
    );
    _isInitialized = true;
  }

  Future<List<PeminjamanItem>> ambilSemuaPeminjaman() async {
    await init();
    final jumlahFn = _contract.function('jumlahPeminjaman');
    final ambilFn = _contract.function('ambilPeminjaman');

    final countResult = await _client.call(
      contract: _contract,
      function: jumlahFn,
      params: [],
    );
    final int total = (countResult.first as BigInt).toInt();

    final List<PeminjamanItem> hasil = [];
    for (int i = 0; i < total; i++) {
      final res = await _client.call(
        contract: _contract,
        function: ambilFn,
        params: [BigInt.from(i)],
      );
      final bool dihapus = res[4] as bool;
      if (dihapus) continue; // Lewati catatan yang sudah dihapus

      final int tsPinjam = (res[2] as BigInt).toInt();
      final int tsKembali = (res[3] as BigInt).toInt();

      hasil.add(
        PeminjamanItem(
          id: i,
          namaAlat: res[0] as String,
          peminjam: (res[1] as EthereumAddress).hexEip55,
          waktuPinjam: DateTime.fromMillisecondsSinceEpoch(tsPinjam * 1000),
          waktuKembali: tsKembali == 0
              ? null
              : DateTime.fromMillisecondsSinceEpoch(tsKembali * 1000),
          dihapus: dihapus,
        ),
      );
    }
    return hasil.reversed.toList();
  }

  /// Menyusun data hex (calldata) untuk dikirimkan ke WalletConnect / Reown AppKit
  Uint8List encodeFunctionCall(String functionName, List<dynamic> params) {
    final fn = _contract.function(functionName);
    return fn.encodeCall(params);
  }

  /// Bonus: Mendengarkan event kontrak agar daftar otomatis terbarui lintas HP
  Stream<FilterEvent> dengarkanSemuaEvent() {
    return _client.events(
      FilterOptions.events(
        contract: _contract,
        event: _contract.event('AlatDipinjam'),
      ),
    );
  }

  Stream<FilterEvent> dengarkanEventKembali() {
    return _client.events(
      FilterOptions.events(
        contract: _contract,
        event: _contract.event('AlatDikembalikan'),
      ),
    );
  }

  void dispose() {
    _client.dispose();
  }
}