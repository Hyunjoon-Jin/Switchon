import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/glass.dart';
import '../community/community_screen.dart';
import '../fasting/fasting_floating_timer.dart';
import '../fasting/fasting_screen.dart';
import '../home/home_screen.dart';
import '../home/widgets/quick_log_sheet.dart';
import '../meals/meals_screen.dart';
import '../stats/stats_screen.dart';

/// 하단 탭 셸 — 오늘 / 단식 / 기록 / 알림.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    FastingScreen(),
    MealsScreen(),
    StatsScreen(),
    CommunityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 기록 탭(2)과 단식 탭(1)은 자체 FAB / 화면이 있으므로 제외
      floatingActionButton: (_index == 1 || _index == 2)
          ? null
          : FloatingActionButton(
              heroTag: 'quick_log_fab',
              tooltip: '빠른 기록',
              onPressed: () => showQuickLogSheet(context),
              child: const Icon(Icons.add),
            ),
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          // 단식 진행 중이면 우측 하단에 떠 있는 타이머(단식 탭에선 숨김).
          if (_index != 1)
            Positioned(
              right: 16,
              bottom: 72,
              child: FastingFloatingTimer(
                onTap: () => setState(() => _index = 1),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassCard(
          padding: EdgeInsets.zero,
          radius: 28,
          blur: 24,
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '오늘',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: '단식',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: '기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '통계',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: '커뮤니티',
          ),
            ],
          ),
        ),
      ),
    );
  }
}
