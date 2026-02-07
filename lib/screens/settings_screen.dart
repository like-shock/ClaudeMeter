import 'package:flutter/material.dart';
import '../models/config.dart';

/// Settings screen.
class SettingsScreen extends StatefulWidget {
  final AppConfig config;
  final bool isLoggedIn;
  final Function(AppConfig) onSave;
  final VoidCallback onLogout;
  final VoidCallback onClose;

  const SettingsScreen({
    super.key,
    required this.config,
    required this.isLoggedIn,
    required this.onSave,
    required this.onLogout,
    required this.onClose,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppConfig _localConfig;

  @override
  void initState() {
    super.initState();
    _localConfig = widget.config;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection('표시 항목', [
                  _buildCheckbox('5시간 세션', _localConfig.showFiveHour,
                      (v) => _updateConfig(showFiveHour: v)),
                  _buildCheckbox('주간 전체', _localConfig.showSevenDay,
                      (v) => _updateConfig(showSevenDay: v)),
                  _buildCheckbox('Sonnet 주간', _localConfig.showSonnet,
                      (v) => _updateConfig(showSonnet: v)),
                ]),
                const SizedBox(height: 24),
                _buildSection('갱신 주기', [
                  _buildSlider(),
                ]),
                const SizedBox(height: 24),
                _buildSection('계정', [
                  if (widget.isLoggedIn)
                    _buildLogoutButton()
                  else
                    const Text(
                      '로그인되지 않음',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                    ),
                ]),
              ],
            ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
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
            '설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: const Icon(
              Icons.close,
              size: 18,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8E8E93),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? const Color(0xFF007AFF) : Colors.transparent,
                border: Border.all(
                  color: value
                      ? const Color(0xFF007AFF)
                      : const Color(0xFFC7C7CC),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider() {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF007AFF),
              inactiveTrackColor: const Color(0xFFE5E5EA),
              thumbColor: const Color(0xFF007AFF),
              overlayColor: const Color(0xFF007AFF).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _localConfig.refreshIntervalSeconds.toDouble(),
              min: 10,
              max: 300,
              divisions: 29,
              onChanged: (v) => _updateConfig(refreshIntervalSeconds: v.round()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${_localConfig.refreshIntervalSeconds}초',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1D1D1F),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: widget.onLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
          border: Border.all(
            color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '로그아웃',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFFF3B30),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: const Border(
          top: BorderSide(
            color: Color(0xFFD1D1D6),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '취소',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onSave(_localConfig),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '저장',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateConfig({
    bool? showFiveHour,
    bool? showSevenDay,
    bool? showSonnet,
    int? refreshIntervalSeconds,
  }) {
    setState(() {
      _localConfig = _localConfig.copyWith(
        showFiveHour: showFiveHour,
        showSevenDay: showSevenDay,
        showSonnet: showSonnet,
        refreshIntervalSeconds: refreshIntervalSeconds,
      );
    });
  }
}
