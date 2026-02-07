import 'package:flutter/material.dart';
import '../models/usage_data.dart';
import '../models/config.dart';
import '../widgets/usage_bar.dart';
import '../widgets/login_view.dart';

/// Home screen showing usage data.
class HomeScreen extends StatelessWidget {
  final bool isLoggedIn;
  final bool isLoading;
  final String? loginError;
  final UsageData? usageData;
  final AppConfig config;
  final VoidCallback onLogin;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;

  const HomeScreen({
    super.key,
    required this.isLoggedIn,
    required this.isLoading,
    this.loginError,
    this.usageData,
    required this.config,
    required this.onLogin,
    required this.onRefresh,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTitleBar(),
        Expanded(
          child: isLoggedIn
              ? _buildUsageContent()
              : LoginView(
                  isLoading: isLoading,
                  error: loginError,
                  onLogin: onLogin,
                ),
        ),
      ],
    );
  }

  Widget _buildTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF313244).withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFF45475A),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Claude Monitor',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCDD6F4),
            ),
          ),
          const Spacer(),
          _buildIconButton(
            icon: Icons.refresh,
            onTap: isLoading || !isLoggedIn ? null : onRefresh,
            isLoading: isLoading,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.settings,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF89B4FA),
                ),
              )
            : Icon(
                icon,
                size: 16,
                color: onTap == null
                    ? const Color(0xFF6C7086)
                    : const Color(0xFFA6ADC8),
              ),
      ),
    );
  }

  Widget _buildUsageContent() {
    final data = usageData ?? UsageData.empty();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (config.showFiveHour)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UsageBar(
                label: '5시간 세션',
                tier: data.fiveHour,
              ),
            ),
          if (config.showSevenDay)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UsageBar(
                label: '주간 전체',
                tier: data.sevenDay,
              ),
            ),
          if (config.showSonnet)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UsageBar(
                label: 'Sonnet 주간',
                tier: data.sevenDaySonnet,
              ),
            ),
          if (usageData != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '마지막 업데이트: ${_formatTime(data.fetchedAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6C7086),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}
