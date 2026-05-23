import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_colors.dart';
import '../services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSignup() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이메일과 비밀번호를 입력해주세요.")),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("비밀번호가 일치하지 않습니다.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.instance.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        if (response.user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("회원가입 성공! 이메일 인증을 확인하거나 로그인해주세요.")),
          );
          Navigator.pop(context); // 로그인 화면으로 이동
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("알 수 없는 오류가 발생했습니다."), backgroundColor: Colors.redAccent),
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: -0.8,
                  ),
                  children: [
                    TextSpan(text: "Create\n"),
                    TextSpan(
                      text: "Account",
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Sign up to start your running journey",
                style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 36),
              _buildTextField(_emailController, "Email Address", Icons.email_outlined),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, "Password", Icons.lock_outline, isPassword: true),
              const SizedBox(height: 16),
              _buildTextField(_confirmPasswordController, "Confirm Password", Icons.lock_reset_outlined, isPassword: true),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSignup,
                style: ElevatedButton.styleFrom(
                  shadowColor: Colors.transparent,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "Sign Up",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 30),
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
