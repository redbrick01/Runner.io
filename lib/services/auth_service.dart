import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return Supabase.instance.client.auth.signOut();
  }
}
