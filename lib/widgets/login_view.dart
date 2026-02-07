import 'package:flutter/material.dart';

/// Login view widget with one-click OAuth flow.
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
            Text(
              isLoading
                  ? '브라우저에서 Claude에 로그인해주세요.\n인증이 완료되면 자동으로 연결됩니다.'
                  : 'Claude AI 사용량을 확인하려면\n로그인이 필요합니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFA6ADC8),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: isLoading ? null : onLogin,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF89B4FA), Color(0xFFB4BEFE)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isLoading
                      ? null
                      : [
                          BoxShadow(
                            color:
                                const Color(0xFF89B4FA).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1E1E2E),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      isLoading ? '인증 대기 중...' : 'Claude 로그인',
                      style: const TextStyle(
                        color: Color(0xFF1E1E2E),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
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
}
