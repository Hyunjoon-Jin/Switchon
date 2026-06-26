import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../auth/sign_in_screen.dart';
import '../shell/main_shell.dart';
import 'onboarding_flow.dart';

/// 인증 + 온보딩 상태에 따라 첫 화면을 분기하는 라우팅 게이트.
///
///   미로그인           → SignInScreen
///   로그인 + 온보딩 미완 → OnboardingFlow (안전 고지 → 나이 게이트 → 프로그램 설정)
///   로그인 + 온보딩 완료 → HomeScreen
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const _Loading(),
      error: (e, _) => _ErrorView(message: '$e'),
      data: (state) {
        final signedIn = state.session != null;
        if (!signedIn) {
          return const SignInScreen();
        }

        final profileAsync = ref.watch(profileProvider);
        return profileAsync.when(
          loading: () => const _Loading(),
          error: (e, _) => _ErrorView(message: '$e'),
          data: (profile) {
            if (profile == null || !profile.hasCompletedOnboarding) {
              return const OnboardingFlow();
            }
            return const MainShell();
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('문제가 발생했습니다.\n$message'),
        ),
      ),
    );
  }
}
