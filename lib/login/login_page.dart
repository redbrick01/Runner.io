import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_colors.dart';
import '../main/running_map_page.dart';
import '../services/auth_service.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이메일과 비밀번호를 입력해주세요.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        // 로그인 성공 시 메인 지도로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RunningMapPage()),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("알 수 없는 오류가 발생했습니다."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(
                    Icons.flutter_dash_rounded,
                    size: 50,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -1.2,
                    ),
                    children: [
                      TextSpan(text: "RUNNER"),
                      TextSpan(
                        text: ".IO",
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Run and Conquer your territory",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 44),
              _buildTextField(_emailController, "Email address", Icons.email_outlined),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, "Password", Icons.lock_outline, isPassword: true),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  shadowColor: Colors.transparent,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "Get Started",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: AppColors.secondaryText)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignupPage()),
                      );
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: AppColors.secondaryText),
        prefixIcon: Icon(icon, size: 20, color: AppColors.secondaryText),
        fillColor: AppColors.surface,
      ),
    );
  }
}
