import 'package:supabase_flutter/supabase_flutter.dart';

/// 이메일/비밀번호 기반 인증 (MVP). 추후 OAuth(Apple/Google)로 확장 가능.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

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
