import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// 이메일/비밀번호 + 구글 OAuth 인증.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// 구글 로그인. 웹에서는 현재 주소로 리디렉트되어 돌아오며,
  /// Supabase 가 돌아온 세션을 자동으로 인식한다.
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      // 웹은 현재 origin 으로 자동 복귀. 네이티브는 딥링크 사용(추후).
      redirectTo: kIsWeb ? null : 'io.supabase.switchon://login-callback',
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email);
}
