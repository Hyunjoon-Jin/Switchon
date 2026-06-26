import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'features/setup_required_screen.dart';

class SwitchOnApp extends ConsumerWidget {
  const SwitchOnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '스위치온',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: AppConfig.isSupabaseConfigured
          ? const OnboardingGate()
          : const SetupRequiredScreen(),
    );
  }
}
