import 'package:flutter/material.dart';
import '../models/cost_data.dart';
import '../widgets/cost_bar.dart';

/// Screen displaying Claude Code API usage costs.
class CostScreen extends StatelessWidget {
  final CostData? costData;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  const CostScreen({
    super.key,
    this.costData,
    required this.isLoading,
    this.error,
    required this.onRefresh,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
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
          GestureDetector(
            onTap: onClose,
            child: const Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Color(0xFF007AFF),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'API 사용 요금',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: isLoading ? null : onRefresh,
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
                    Icons.refresh,
                    size: 16,
                    color: isLoading
                        ? const Color(0xFFC7C7CC)
                        : const Color(0xFF8E8E93),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading && costData == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF007AFF)),
            SizedBox(height: 12),
            Text(
              'JSONL 파일 분석 중...',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_off_outlined,
                size: 32,
                color: Color(0xFFC7C7CC),
              ),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = costData ?? CostData.empty();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Total cost summary
          _buildCostSummary(data),
          const SizedBox(height: 12),
          // Model breakdown
          if (data.modelBreakdown.isNotEmpty) ...[
            _buildModelBreakdown(data),
            const SizedBox(height: 12),
          ],
          // Daily costs (recent 7 days)
          if (data.dailyCosts.isNotEmpty)
            _buildRecentDays(data),
          // Stats
          const SizedBox(height: 12),
          _buildStats(data),
        ],
      ),
    );
  }

  Widget _buildCostSummary(CostData data) {
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.attach_money, size: 14, color: Color(0xFF636366)),
                  SizedBox(width: 4),
                  Text(
                    '오늘 사용 요금',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ],
              ),
              Text(
                '\$${data.todayCost.toStringAsFixed(4)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          const Divider(height: 16, thickness: 0.5, color: Color(0xFFE5E5EA)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.functions, size: 14, color: Color(0xFF636366)),
                  SizedBox(width: 4),
                  Text(
                    '전체 누적 요금',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ],
              ),
              Text(
                '\$${data.totalCost.toStringAsFixed(4)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelBreakdown(CostData data) {
    final maxCost = data.modelBreakdown.isNotEmpty
        ? data.modelBreakdown.first.cost
        : 0.0;

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
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 14, color: Color(0xFF636366)),
              SizedBox(width: 4),
              Text(
                '모델별 사용 요금',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...data.modelBreakdown.map((m) => CostBar(
                modelCost: m,
                maxCost: maxCost,
              )),
        ],
      ),
    );
  }

  Widget _buildRecentDays(CostData data) {
    // Show up to 7 most recent days
    final recent = data.dailyCosts.length > 7
        ? data.dailyCosts.sublist(data.dailyCosts.length - 7)
        : data.dailyCosts;

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
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: Color(0xFF636366)),
              SizedBox(width: 4),
              Text(
                '최근 7일',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recent.reversed.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(d.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF636366),
                      ),
                    ),
                    Text(
                      '\$${d.cost.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStats(CostData data) {
    final dateRange = (data.oldestSession != null && data.newestSession != null)
        ? '${_formatDate(data.oldestSession!)} ~ ${_formatDate(data.newestSession!)}'
        : '-';

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
        children: [
          _buildStatRow('세션 수', '${data.totalSessions}개'),
          _buildStatRow('JSONL 파일', '${data.totalFiles}개'),
          _buildStatRow('기간', dateRange),
          if (data.fetchedAt.year > 0)
            _buildStatRow('마지막 계산', _formatTime(data.fetchedAt)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E8E93),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF636366),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}
