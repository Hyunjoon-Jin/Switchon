import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// 닉네임이 없으면 입력 다이얼로그로 받아 저장하고 반환. 취소 시 null.
Future<String?> ensureNickname(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(profileProvider).valueOrNull;
  final existing = profile?.displayName;
  if (existing != null && existing.trim().isNotEmpty) return existing;

  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('닉네임 설정'),
      content: TextField(
        controller: controller,
        maxLength: 20,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '커뮤니티에서 보일 이름',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) Navigator.pop(ctx, v);
          },
          child: const Text('저장'),
        ),
      ],
    ),
  );

  if (name == null || name.isEmpty) return null;
  await ref.read(communityServiceProvider).updateDisplayName(name);
  ref.invalidate(profileProvider);
  return name;
}
