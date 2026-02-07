import 'package:flutter/material.dart';

/// Login view widget.
class LoginView extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback onLogin;

  const LoginView({
    super.key,
    required this.isLoading,
    this.error,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Claude AI 사용량을 확인하려면\n로그인이 필요합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFA6ADC8),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            _buildLoginButton(),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: const TextStyle(
                  color: Color(0xFFF38BA8),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: isLoading ? null : onLogin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF89B4FA), Color(0xFFB4BEFE)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF89B4FA).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Text(
          isLoading ? '로그인 중...' : 'Claude 로그인',
          style: const TextStyle(
            color: Color(0xFF1E1E2E),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
