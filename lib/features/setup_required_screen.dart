import 'package:flutter/material.dart';

/// Supabase 환경변수가 주입되지 않았을 때 표시되는 안내 화면.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.settings_suggest_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Supabase 설정이 필요합니다',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'SUPABASE_URL 과 SUPABASE_ANON_KEY 를 --dart-define 으로 '
                  '주입한 뒤 다시 실행하세요.\n\n'
                  'flutter run \\\n'
                  '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                  '  --dart-define=SUPABASE_ANON_KEY=eyJ...',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
