import 'package:flutter/material.dart';
import '../models/config.dart';

/// Mode selection screen displayed on first launch.
class ModeSelectScreen extends StatelessWidget {
  final void Function(AppMode mode) onModeSelected;

  const ModeSelectScreen({
    super.key,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Claude Meter',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 8),
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
