import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Login flow state.
enum LoginState {
  initial,
  waitingForCode,
  exchangingToken,
}

/// Login view widget with two-step OAuth flow.
class LoginView extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final Future<void> Function() onStartLogin;
  final Future<bool> Function(String code) onSubmitCode;

  const LoginView({
    super.key,
    required this.isLoading,
    this.error,
    required this.onStartLogin,
    required this.onSubmitCode,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  LoginState _state = LoginState.initial;
  final _codeController = TextEditingController();
  String? _localError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleStartLogin() async {
    setState(() {
      _localError = null;
    });

    try {
      await widget.onStartLogin();
      setState(() {
        _state = LoginState.waitingForCode;
      });
    } catch (e) {
      setState(() {
        _localError = '브라우저를 열 수 없습니다.';
      });
    }
  }

  Future<void> _handleSubmitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _localError = '인증 코드를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    try {
      final success = await widget.onSubmitCode(code);
      if (!success) {
        setState(() {
          _localError = '인증에 실패했습니다. 코드를 확인해주세요.';
          _isSubmitting = false;
        });
      }
      // If success, parent widget will handle state change
    } catch (e) {
      setState(() {
        _localError = '오류가 발생했습니다: $e';
        _isSubmitting = false;
      });
    }
  }

  void _handleCancel() {
    setState(() {
      _state = LoginState.initial;
      _codeController.clear();
      _localError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _localError ?? widget.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_state == LoginState.initial) ...[
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
            ] else if (_state == LoginState.waitingForCode) ...[
              const Text(
                '브라우저에서 Claude에 로그인하고\n표시된 인증 코드를 복사해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFA6ADC8),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              _buildCodeInput(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCancelButton(),
                  const SizedBox(width: 12),
                  _buildSubmitButton(),
                ],
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
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

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: widget.isLoading ? null : _handleStartLogin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF89B4FA), Color(0xFFB4BEFE)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: widget.isLoading
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF89B4FA).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Text(
          widget.isLoading ? '로그인 중...' : 'Claude 로그인',
          style: const TextStyle(
            color: Color(0xFF1E1E2E),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF313244),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF45475A),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _codeController,
        enabled: !_isSubmitting,
        style: const TextStyle(
          color: Color(0xFFCDD6F4),
          fontSize: 14,
          fontFamily: 'monospace',
        ),
        decoration: const InputDecoration(
          hintText: '인증 코드 붙여넣기',
          hintStyle: TextStyle(
            color: Color(0xFF6C7086),
            fontSize: 14,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
        ),
        textAlign: TextAlign.center,
        onSubmitted: (_) => _handleSubmitCode(),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _handleCancel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF313244),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF45475A),
            width: 1,
          ),
        ),
        child: const Text(
          '취소',
          style: TextStyle(
            color: Color(0xFFA6ADC8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _handleSubmitCode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF89B4FA), Color(0xFFB4BEFE)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _isSubmitting ? '확인 중...' : '확인',
          style: const TextStyle(
            color: Color(0xFF1E1E2E),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
