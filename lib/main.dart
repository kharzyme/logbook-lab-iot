import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'config/app_config.dart';
import 'services/blockchain_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const LogbookLabApp());
}

class LogbookLabApp extends StatelessWidget {
  const LogbookLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logbook Lab IoT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00695C),
        useMaterial3: true,
      ),
      home: const LogbookHomePage(),
    );
  }
}

enum FilterStatus { semua, dipinjam, selesai, milikSaya }

class LogbookHomePage extends StatefulWidget {
  const LogbookHomePage({super.key});

  @override
  State<LogbookHomePage> createState() => _LogbookHomePageState();
}

class _LogbookHomePageState extends State<LogbookHomePage> {
  final BlockchainService _blockchain = BlockchainService();
  final TextEditingController _alatController = TextEditingController();

  ReownAppKitModal? _appKitModal;
  List<PeminjamanItem> _semuaData = [];
  FilterStatus _filterAktif = FilterStatus.semua;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _statusPesan;
  String? _lastTxHash;
  bool _isError = false;

  StreamSubscription? _subPinjam;
  StreamSubscription? _subKembali;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _blockchain.init();
    await _initReownAppKit();
    await _muatData();
    _pasangEventListener();
  }

  Future<void> _initReownAppKit() async {
    final modal = ReownAppKitModal(
      context: context,
      projectId: AppConfig.reownProjectId,
      metadata: const PairingMetadata(
        name: 'Logbook Lab IoT',
        description: 'Aplikasi Peminjaman Alat Lab IoT Terdesentralisasi',
        url: 'https://logbooklab.iot',
        icons: ['https://avatars.githubusercontent.com/u/37784886'],
        redirect: Redirect(
          native: 'logbooklab://',
          universal: 'https://logbooklab.iot',
        ),
      ),
      optionalNamespaces: {
        'eip155': RequiredNamespace(
          chains: ['eip155:${AppConfig.chainId}'],
          methods: [
            'eth_sendTransaction',
            'personal_sign',
            'eth_signTypedData',
          ],
          events: ['chainChanged', 'accountsChanged'],
        ),
      },
    );

    await modal.init();
    modal.addListener(() {
      if (mounted) setState(() {});
    });

    if (mounted) {
      setState(() => _appKitModal = modal);
    }
  }

  void _pasangEventListener() {
    _subPinjam = _blockchain.dengarkanSemuaEvent().listen((_) {
      _muatData(silent: true);
    });
    _subKembali = _blockchain.dengarkanEventKembali().listen((_) {
      _muatData(silent: true);
    });
  }

  String? get _connectedAddress {
    if (_appKitModal == null || !_appKitModal!.isConnected) return null;
    final session = _appKitModal!.session;
    if (session == null) return null;
    final accounts = session.getAccounts() ?? [];
    if (accounts.isEmpty) return null;
    // Format akun Reown: "eip155:11155111:0xAbC..."
    return accounts.first.split(':').last;
  }

  Future<void> _muatData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final data = await _blockchain.ambilSemuaPeminjaman();
      if (mounted) {
        setState(() {
          _semuaData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _statusPesan = 'Gagal membaca data kontrak: $e';
        });
      }
    }
  }

  Future<void> _kirimTransaksiKontrak({
    required String namaFungsi,
    required List<dynamic> params,
    required String labelProses,
  }) async {
    final sender = _connectedAddress;
    if (sender == null || _appKitModal?.session == null) {
      setState(() {
        _isError = true;
        _lastTxHash = null;
        _statusPesan = 'Hubungkan wallet (MetaMask) terlebih dahulu!';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isError = false;
      _lastTxHash = null;
      _statusPesan = '$labelProses — konfirmasi di MetaMask...';
    });

    try {
      final calldata = _blockchain.encodeFunctionCall(namaFungsi, params);
      final hexData =
          '0x${calldata.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';



      final txHash = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic,
        chainId: 'eip155:${AppConfig.chainId}',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [
            {
              'from': sender,
              'to': AppConfig.contractAddress,
              'data': hexData,
            }
          ],
        ),
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isError = false;
          _lastTxHash = txHash.toString();
          _statusPesan = 'Transaksi terkirim! Menunggu konfirmasi blok Sepolia...';
        });
      }

      // Tunggu konfirmasi blok Sepolia (~14 detik) lalu muat ulang
      await Future.delayed(const Duration(seconds: 15));
      await _muatData(silent: true);
    } catch (e) {
      if (mounted) {
        String pesan = e.toString();
        if (pesan.contains('sedang dipinjam')) {
          pesan = 'Ditolak Kontrak: Alat ini sedang dipinjam oleh akun lain!';
        } else if (pesan.toLowerCase().contains('reject') ||
            pesan.toLowerCase().contains('denied')) {
          pesan = 'Transaksi dibatalkan oleh pengguna di MetaMask.';
        }
        setState(() {
          _isSubmitting = false;
          _isError = true;
          _lastTxHash = null;
          _statusPesan = pesan;
        });
      }
    }
  }

  Future<void> _prosesPinjam() async {
    final nama = _alatController.text.trim();
    if (nama.isEmpty) return;
    FocusScope.of(context).unfocus();
    await _kirimTransaksiKontrak(
      namaFungsi: 'pinjamAlat',
      params: [nama],
      labelProses: 'Meminjam "$nama"',
    );
    if (!_isError) _alatController.clear();
  }

  Future<void> _tampilkanDialogEdit(PeminjamanItem item) async {
    final editCtrl = TextEditingController(text: item.namaAlat);
    final namaBaru = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Nama Alat'),
        content: TextField(
          controller: editCtrl,
          decoration: const InputDecoration(
            labelText: 'Nama Alat Baru',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, editCtrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (namaBaru != null && namaBaru.isNotEmpty && namaBaru != item.namaAlat) {
      await _kirimTransaksiKontrak(
        namaFungsi: 'editNamaAlat',
        params: [BigInt.from(item.id), namaBaru],
        labelProses: 'Mengubah nama alat',
      );
    }
  }

  List<PeminjamanItem> get _dataTerfilter {
    final myAddr = _connectedAddress?.toLowerCase();
    return _semuaData.where((item) {
      switch (_filterAktif) {
        case FilterStatus.dipinjam:
          return !item.sudahKembali;
        case FilterStatus.selesai:
          return item.sudahKembali;
        case FilterStatus.milikSaya:
          return myAddr != null && item.peminjam.toLowerCase() == myAddr;
        case FilterStatus.semua:
          return true;
      }
    }).toList();
  }

  String _formatAlamat(String addr) {
    if (addr.length < 10) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  @override
  void dispose() {
    _subPinjam?.cancel();
    _subKembali?.cancel();
    _alatController.dispose();
    _blockchain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _connectedAddress;
    final listTampil = _dataTerfilter;
    final fmtWaktu = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logbook Lab IoT'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          if (_appKitModal != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AppKitModalConnectButton(appKit: _appKitModal!),
            ),
          IconButton(
            tooltip: 'Muat Ulang',
            onPressed: () => _muatData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _muatData(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner Status Koneksi Wallet
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: connected != null
                    ? Colors.teal.shade50
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: connected != null
                      ? Colors.teal.shade200
                      : Colors.amber.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    connected != null ? Icons.verified_user : Icons.wallet,
                    size: 18,
                    color: connected != null
                        ? Colors.teal.shade800
                        : Colors.amber.shade900,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connected != null
                          ? 'Wallet Aktif: ${_formatAlamat(connected)} • ${_semuaData.length} catatan'
                          : 'Belum terhubung ke Wallet. Klik Connect untuk login via MetaMask.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: connected != null
                            ? Colors.teal.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Form Tambah Peminjaman
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _alatController,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      hintText: 'Nama Alat Lab IoT (cth: ESP32)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _prosesPinjam,
                  icon: const Icon(Icons.add),
                  label: const Text('Pinjam'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Indikator Status Transaksi (+ Hash & Error)
            if (_statusPesan != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        _isError ? Colors.red.shade200 : Colors.blue.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_isSubmitting)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _isError ? Icons.error_outline : Icons.check_circle,
                            size: 18,
                            color: _isError ? Colors.red : Colors.blue.shade700,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusPesan!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _isError
                                  ? Colors.red.shade900
                                  : Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_lastTxHash != null) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _lastTxHash!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transaction Hash disalin!'),
                            ),
                          );
                        },
                        child: Text(
                          'Tx Hash: ${_formatAlamat(_lastTxHash!)} (ketuk untuk salin)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Bar Filter Bonus (Semua, Dipinjam, Selesai, Milik Saya)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua', FilterStatus.semua),
                  const SizedBox(width: 6),
                  _buildFilterChip('Dipinjam', FilterStatus.dipinjam),
                  const SizedBox(width: 6),
                  _buildFilterChip('Selesai', FilterStatus.selesai),
                  const SizedBox(width: 6),
                  _buildFilterChip('Milik Saya', FilterStatus.milikSaya),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Daftar Catatan Peminjaman
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (listTampil.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('Belum ada catatan pada filter ini.'),
                ),
              )
            else
              ...listTampil.map((item) {
                final isOwner = connected != null &&
                    item.peminjam.toLowerCase() == connected.toLowerCase();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: item.sudahKembali
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          child: Icon(
                            item.sudahKembali
                                ? Icons.check
                                : Icons.assignment_late_outlined,
                            color: item.sudahKembali
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.namaAlat,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: item.sudahKembali
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Peminjam: ${_formatAlamat(item.peminjam)}${isOwner ? " (Anda)" : ""}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              Text(
                                'Pinjam: ${fmtWaktu.format(item.waktuPinjam)}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              if (item.sudahKembali)
                                Text(
                                  'Kembali: ${fmtWaktu.format(item.waktuKembali!)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Aksi Tombol Sesuai Status & Kepemilikan Wallet
                        if (!item.sudahKembali && isOwner)
                          Column(
                            children: [
                              OutlinedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _kirimTransaksiKontrak(
                                          namaFungsi: 'kembalikanAlat',
                                          params: [BigInt.from(item.id)],
                                          labelProses:
                                              'Mengembalikan "${item.namaAlat}"',
                                        ),
                                child: const Text('Kembalikan'),
                              ),
                              TextButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _tampilkanDialogEdit(item),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                              ),
                            ],
                          )
                        else if (item.sudahKembali && isOwner)
                          Column(
                            children: [
                              Chip(
                                label: const Text('Selesai'),
                                backgroundColor: Colors.green.shade50,
                              ),
                              IconButton(
                                tooltip: 'Hapus Riwayat',
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _kirimTransaksiKontrak(
                                          namaFungsi: 'hapusCatatan',
                                          params: [BigInt.from(item.id)],
                                          labelProses: 'Menghapus catatan',
                                        ),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                              ),
                            ],
                          )
                        else
                          Chip(
                            label: Text(
                              item.sudahKembali ? 'Selesai' : 'Dipinjam',
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, FilterStatus status) {
    return ChoiceChip(
      label: Text(label),
      selected: _filterAktif == status,
      onSelected: (_) => setState(() => _filterAktif = status),
    );
  }
}