import 'package:flutter/material.dart';
import '../models/usage_data.dart';

/// A progress bar widget for displaying usage.
class UsageBar extends StatelessWidget {
  final String label;
  final UsageTier tier;

  const UsageBar({
    super.key,
    required this.label,
    required this.tier,
  });

  Color _getBarColor(double utilization) {
    // utilization is 0-100 (percentage)
    if (utilization >= 90) return const Color(0xFFFF3B30); // Red
    if (utilization >= 70) return const Color(0xFFFF9500); // Orange
    if (utilization >= 50) return const Color(0xFFFFCC00); // Yellow
    return const Color(0xFF34C759); // Green
  }

  String _formatResetTime(DateTime? resetsAt) {
    if (resetsAt == null) return '';

    final now = DateTime.now();
    final diff = resetsAt.difference(now);

    if (diff.isNegative) return '곧 리셋';

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours > 24) {
      final days = hours ~/ 24;
      return '$days일 후 리셋';
    }

    if (hours > 0) {
      return '$hours시간 $minutes분 후 리셋';
    }

    return '$minutes분 후 리셋';
  }

  @override
  Widget build(BuildContext context) {
    final percentage = tier.percentage;
    final barColor = _getBarColor(tier.utilization);
    final resetInfo = _formatResetTime(tier.resetsAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD1D1D6),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              // utilization is 0-100, convert to 0-1 for widthFactor
              widthFactor: (tier.utilization / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Reset info
          if (resetInfo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                resetInfo,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
