import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (AppConfig.isSupabaseConfigured) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    }
    runApp(const ProviderScope(child: SwitchOnApp()));
  } catch (e, st) {
    // 시작 중 오류가 나면 흰 화면 대신 원인을 보여준다(진단 + 안전).
    runApp(_BootError(message: '$e', detail: '$st'));
  }
}

class _BootError extends StatelessWidget {
  const _BootError({required this.message, required this.detail});
  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                const Text('시작 중 문제가 발생했어요',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(message,
                    style: const TextStyle(color: Color(0xFFB00020))),
                const SizedBox(height: 16),
                Text(detail,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
