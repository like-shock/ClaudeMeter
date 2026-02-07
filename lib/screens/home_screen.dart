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
  final String? usageError;
  final String? userEmail;
  final String? subscriptionType;
  final UsageData? usageData;
  final AppConfig config;
  final VoidCallback onLogin;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onQuit;

  const HomeScreen({
    super.key,
    required this.isLoggedIn,
    required this.isLoading,
    this.loginError,
    this.usageError,
    this.userEmail,
    this.subscriptionType,
    this.usageData,
    required this.config,
    required this.onLogin,
    required this.onRefresh,
    required this.onSettings,
    required this.onQuit,
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
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E5E5),
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
              color: Color(0xFF1D1D1F),
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
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.power_settings_new,
            onTap: onQuit,
            color: const Color(0xFFFF3B30),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onTap,
    bool isLoading = false,
    Color? color,
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
                  color: Color(0xFF007AFF),
                ),
              )
            : Icon(
                icon,
                size: 16,
                color: onTap == null
                    ? const Color(0xFFC7C7CC)
                    : (color ?? const Color(0xFF8E8E93)),
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
          // Error message
          if (usageError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF3B30),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      usageError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
          // User info and last update
          if (usageData != null) ...[
            const SizedBox(height: 8),
            if (userEmail != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 14,
                      color: Color(0xFF8E8E93),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      userEmail!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    if (subscriptionType != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          subscriptionType!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Text(
              '마지막 업데이트: ${_formatTime(data.fetchedAt)}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
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
