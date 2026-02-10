import 'package:flutter/material.dart';
import '../models/cost_data.dart';
import '../utils/constants.dart';
import '../utils/pricing.dart';
import '../widgets/cost_bar.dart';

/// API mode main screen with Current/History tabs.
class ApiHomeScreen extends StatefulWidget {
  final CostData? costData;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onModeChange;
  final VoidCallback onQuit;

  const ApiHomeScreen({
    super.key,
    this.costData,
    required this.isLoading,
    this.error,
    required this.onRefresh,
    required this.onModeChange,
    required this.onQuit,
  });

  @override
  State<ApiHomeScreen> createState() => _ApiHomeScreenState();
}

class _ApiHomeScreenState extends State<ApiHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Currently viewed month for the History tab.
  late DateTime _historyMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _historyMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCurrentTab(),
              _buildHistoryTab(),
            ],
          ),
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
          const Text(
            'API Mode',
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
              color: Color(0xFFC7C7CC),
            ),
          ),
          const Spacer(),
          _buildIconButton(
            icon: Icons.refresh,
            onTap: widget.isLoading ? null : widget.onRefresh,
            isLoading: widget.isLoading,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.swap_horiz,
            onTap: widget.onModeChange,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.power_settings_new,
            onTap: widget.onQuit,
            color: const Color(0xFFFF3B30),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFD1D1D6), width: 0.5),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF007AFF),
        unselectedLabelColor: const Color(0xFF8E8E93),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        indicatorColor: const Color(0xFF007AFF),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: '현재'),
          Tab(text: '기록'),
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

  // ---------------------------------------------------------------------------
  // Current Tab
  // ---------------------------------------------------------------------------

  Widget _buildCurrentTab() {
    if (widget.isLoading && widget.costData == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF007AFF)),
            SizedBox(height: 12),
            Text(
              'JSONL 파일 분석 중...',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined,
                  size: 32, color: Color(0xFFC7C7CC)),
              const SizedBox(height: 12),
              Text(
                widget.error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
      );
    }

    final data = widget.costData ?? CostData.empty();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Compute period summaries from dailyCosts
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    double todayCost = 0;
    int todayTokens = 0;
    double weekCost = 0;
    int weekTokens = 0;
    double monthCost = 0;
    int monthTokens = 0;

    for (final d in data.dailyCosts) {
      final dayDate = DateTime(d.date.year, d.date.month, d.date.day);
      if (dayDate == today) {
        todayCost = d.cost;
        todayTokens = d.totalTokens;
      }
      if (!dayDate.isBefore(weekStart)) {
        weekCost += d.cost;
        weekTokens += d.totalTokens;
      }
      if (!dayDate.isBefore(monthStart)) {
        monthCost += d.cost;
        monthTokens += d.totalTokens;
      }
    }

    // Build model breakdown for current month only
    final monthModelTokens = <String, TokenUsage>{};
    for (final d in data.dailyCosts) {
      final dayDate = DateTime(d.date.year, d.date.month, d.date.day);
      if (!dayDate.isBefore(monthStart)) {
        for (final entry in d.modelTokens.entries) {
          monthModelTokens[entry.key] =
              (monthModelTokens[entry.key] ?? const TokenUsage()) + entry.value;
        }
      }
    }
    final monthModelBreakdown = <ModelCost>[];
    for (final entry in monthModelTokens.entries) {
      if (PricingTable.findPricing(entry.key) == null) continue;
      final cost = PricingTable.calculateCost(entry.key, entry.value);
      monthModelBreakdown.add(ModelCost(
        modelId: entry.key,
        displayName: PricingTable.normalizeModelId(entry.key),
        tokens: entry.value,
        cost: cost,
      ));
    }
    monthModelBreakdown.sort((a, b) => b.cost.compareTo(a.cost));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPeriodSummary(todayCost, todayTokens, weekCost, weekTokens,
              monthCost, monthTokens),
          const SizedBox(height: 12),
          if (monthModelBreakdown.isNotEmpty) ...[
            _buildModelBreakdown(monthModelBreakdown),
            const SizedBox(height: 12),
          ],
          _buildStats(data),
        ],
      ),
    );
  }

  Widget _buildPeriodSummary(
    double todayCost,
    int todayTokens,
    double weekCost,
    int weekTokens,
    double monthCost,
    int monthTokens,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D1D6), width: 0.5),
      ),
      child: Column(
        children: [
          _buildPeriodRow('오늘', todayCost, todayTokens),
          const Divider(height: 12, thickness: 0.5, color: Color(0xFFE5E5EA)),
          _buildPeriodRow('이번 주', weekCost, weekTokens),
          const Divider(height: 12, thickness: 0.5, color: Color(0xFFE5E5EA)),
          _buildPeriodRow('이번 달', monthCost, monthTokens),
        ],
      ),
    );
  }

  Widget _buildPeriodRow(String label, double cost, int tokens) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1D1D1F),
            ),
          ),
        ),
        Expanded(
          child: Text(
            '\$${cost.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF007AFF),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            _formatTokens(tokens),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E8E93),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelBreakdown(List<ModelCost> breakdown) {
    final maxCost = breakdown.isNotEmpty ? breakdown.first.cost : 0.0;
    final total = breakdown.fold<double>(0, (s, m) => s + m.cost);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D1D6), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 14, color: Color(0xFF636366)),
              SizedBox(width: 4),
              Text(
                '모델별 사용 요금 (이번 달)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...breakdown.map((m) {
            final pct = total > 0 ? (m.cost / total * 100) : 0;
            return _buildModelRow(m, maxCost, pct.toDouble());
          }),
        ],
      ),
    );
  }

  Widget _buildModelRow(ModelCost m, double maxCost, double percentage) {
    return CostBar(
      modelCost: m,
      maxCost: maxCost,
      percentage: percentage,
    );
  }

  Widget _buildStats(CostData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D1D6), width: 0.5),
      ),
      child: Column(
        children: [
          _buildStatRow('세션 수', '${data.totalSessions}개'),
          _buildStatRow('JSONL 파일', '${data.totalFiles}개'),
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
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
          Text(value,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF636366))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // History Tab
  // ---------------------------------------------------------------------------

  Widget _buildHistoryTab() {
    if (widget.costData == null) {
      return const Center(
        child: Text(
          '데이터가 없습니다',
          style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
        ),
      );
    }

    final data = widget.costData!;

    // Filter daily costs for the selected month
    final monthDays = data.dailyCosts.where((d) {
      return d.date.year == _historyMonth.year &&
          d.date.month == _historyMonth.month;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final monthTotal = monthDays.fold<double>(0, (s, d) => s + d.cost);
    final avgCost = monthDays.isNotEmpty ? monthTotal / monthDays.length : 0.0;
    final maxDay = monthDays.isNotEmpty
        ? monthDays.reduce((a, b) => a.cost > b.cost ? a : b)
        : null;

    // Find dominant model per day — not available per-day, so show total
    return Column(
      children: [
        // Month navigator
        _buildMonthNavigator(),
        // Summary
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMonthSummary(monthTotal, avgCost, maxDay),
                const SizedBox(height: 12),
                if (monthDays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      '이 달의 데이터가 없습니다',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                  )
                else
                  _buildDayList(monthDays),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _historyMonth = DateTime(
                    _historyMonth.year, _historyMonth.month - 1);
              });
            },
            child: const Icon(Icons.chevron_left,
                size: 20, color: Color(0xFF007AFF)),
          ),
          Text(
            '${_historyMonth.year}년 ${_historyMonth.month}월',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          GestureDetector(
            onTap: () {
              final now = DateTime.now();
              final nextMonth = DateTime(
                  _historyMonth.year, _historyMonth.month + 1);
              if (!nextMonth.isAfter(DateTime(now.year, now.month + 1))) {
                setState(() {
                  _historyMonth = nextMonth;
                });
              }
            },
            child: Icon(
              Icons.chevron_right,
              size: 20,
              color: _canGoForward()
                  ? const Color(0xFF007AFF)
                  : const Color(0xFFC7C7CC),
            ),
          ),
        ],
      ),
    );
  }

  bool _canGoForward() {
    final now = DateTime.now();
    return _historyMonth.year < now.year ||
        (_historyMonth.year == now.year && _historyMonth.month < now.month);
  }

  Widget _buildMonthSummary(
      double total, double average, DailyCost? maxDay) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D1D6), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('합계',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF636366))),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007AFF)),
              ),
            ],
          ),
          const Divider(
              height: 12, thickness: 0.5, color: Color(0xFFE5E5EA)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('일 평균',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
              Text('\$${average.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF636366))),
            ],
          ),
          if (maxDay != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('최대',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                Text(
                    '${maxDay.date.month}/${maxDay.date.day}  \$${maxDay.cost.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF636366))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDayList(List<DailyCost> days) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D1D6), width: 0.5),
      ),
      child: Column(
        children: days.map((d) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '${d.date.month}/${d.date.day}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF636366)),
                  ),
                ),
                Expanded(
                  child: Text(
                    '\$${d.cost.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: Text(
                    _formatTokens(d.totalTokens),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF8E8E93)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  static String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M tok';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(0)}K tok';
    }
    return '$tokens tok';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}
