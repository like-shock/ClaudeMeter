import 'package:flutter/material.dart';
import '../models/cost_data.dart';

/// A bar widget displaying cost for a single model.
class CostBar extends StatelessWidget {
  final ModelCost modelCost;
  final double maxCost;
  final double? percentage;

  const CostBar({
    super.key,
    required this.modelCost,
    required this.maxCost,
    this.percentage,
  });

  Color _getModelColor(String displayName) {
    if (displayName.contains('Opus')) return const Color(0xFFAF52DE); // Purple
    if (displayName.contains('Sonnet')) return const Color(0xFF007AFF); // Blue
    if (displayName.contains('Haiku')) return const Color(0xFF34C759); // Green
    return const Color(0xFF8E8E93); // Gray
  }

  @override
  Widget build(BuildContext context) {
    final color = _getModelColor(modelCost.displayName);
    final fraction = maxCost > 0 ? (modelCost.cost / maxCost).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                modelCost.displayName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${modelCost.cost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (percentage != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${percentage!.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
