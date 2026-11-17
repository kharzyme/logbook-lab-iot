import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get contractAddress => dotenv.env['CONTRACT_ADDRESS'] ?? '';
  static String get rpcUrl => dotenv.env['RPC_URL'] ?? '';
  static int get chainId => int.tryParse(dotenv.env['CHAIN_ID'] ?? '11155111') ?? 11155111;
  static String get reownProjectId => dotenv.env['REOWN_PROJECT_ID'] ?? '';
  static String get abiAssetPath => 'assets/abi/LogbookLabV2.json';
}