import 'package:flutter/material.dart';
import '../models/config.dart';
import '../utils/constants.dart';

/// Mode selection screen displayed on first launch.
class ModeSelectScreen extends StatelessWidget {
  final void Function(AppMode mode) onModeSelected;
  final VoidCallback onQuit;

  const ModeSelectScreen({
    super.key,
    required this.onModeSelected,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTitleBar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '모드를 선택하세요',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 24),
                _buildModeCard(
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFF007AFF),
                  title: 'Plan Mode',
                  description: 'OAuth 구독 사용률 추적',
                  onTap: () => onModeSelected(AppMode.plan),
                ),
                const SizedBox(height: 12),
                _buildModeCard(
                  icon: Icons.attach_money,
                  iconColor: const Color(0xFF34C759),
                  title: 'API Mode',
                  description: 'Claude Code API 비용 추적',
                  onTap: () => onModeSelected(AppMode.api),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7).withValues(alpha: 0.7),
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFD1D1D6),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Claude Meter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'v$appVersion',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onQuit,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.power_settings_new,
                size: 16,
                color: Color(0xFFFF3B30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFD1D1D6),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: Color(0xFFC7C7CC),
            ),
          ],
        ),
      ),
    );
  }
}
