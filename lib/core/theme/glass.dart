import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 앱 전역 배경 — 그라데이션 + 부드러운 광원(글로우). MaterialApp.builder 로 전 화면 뒤에 깔림.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? AppTheme.bgDark : AppTheme.bgLight;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          // 상단 좌측 에메랄드 글로우
          Positioned(
            top: -120,
            left: -80,
            child: _Glow(
              color: AppTheme.emerald.withOpacity(isDark ? 0.22 : 0.18),
              size: 320,
            ),
          ),
          // 하단 우측 틸/스카이 글로우
          Positioned(
            bottom: -140,
            right: -100,
            child: _Glow(
              color: AppTheme.sky.withOpacity(isDark ? 0.18 : 0.16),
              size: 360,
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}

/// 프로스티드 글라스 카드 — 반투명 채움 + 블러 + 하이라이트 테두리.
/// 히어로 요소(네비·중요 카드)에 사용. (성능을 위해 남용하지 않음)
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.blur = 18,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final br = BorderRadius.circular(radius);

    Widget content = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(color: AppTheme.glassBorder(brightness)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(0.10),
                      Colors.white.withOpacity(0.04),
                    ]
                  : [
                      Colors.white.withOpacity(0.65),
                      Colors.white.withOpacity(0.40),
                    ],
            ),
          ),
          child: onTap == null
              ? Padding(padding: padding, child: child)
              : InkWell(
                  borderRadius: br,
                  onTap: onTap,
                  child: Padding(padding: padding, child: child),
                ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: content,
    );
  }
}
