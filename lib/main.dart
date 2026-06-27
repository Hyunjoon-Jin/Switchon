import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        // 웹은 implicit 플로우 사용 — PKCE 의 code_verifier 저장 이슈 회피.
        authOptions: FlutterAuthClientOptions(
          authFlowType:
              kIsWeb ? AuthFlowType.implicit : AuthFlowType.pkce,
        ),
      );
    } catch (_) {
      // 로그인 콜백 처리 실패 등은 치명적이지 않음 — 앱은 그대로 띄워
      // 사용자가 로그인 화면에서 다시 시도할 수 있게 한다.
    }
  }

  runApp(const ProviderScope(child: SwitchOnApp()));
}
