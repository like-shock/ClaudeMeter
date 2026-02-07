// Basic Flutter widget test for Claude Monitor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_monitor_flutter/models/usage_data.dart';
import 'package:claude_monitor_flutter/models/config.dart';
import 'package:claude_monitor_flutter/widgets/usage_bar.dart';
import 'package:claude_monitor_flutter/widgets/login_view.dart';

void main() {
  group('UsageBar', () {
    testWidgets('displays label and percentage', (WidgetTester tester) async {
      const tier = UsageTier(utilization: 0.45);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageBar(
              label: '5시간 세션',
              tier: tier,
            ),
          ),
        ),
      );

      expect(find.text('5시간 세션'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
    });

    testWidgets('shows green color for low usage', (WidgetTester tester) async {
      const tier = UsageTier(utilization: 0.3);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UsageBar(
              label: 'Test',
              tier: tier,
            ),
          ),
        ),
      );

      expect(find.text('30%'), findsOneWidget);
    });
  });

  group('LoginView', () {
    testWidgets('displays login button initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginView(
              isLoading: false,
              onStartLogin: () async {},
              onSubmitCode: (code) async => true,
            ),
          ),
        ),
      );

      expect(find.text('Claude 로그인'), findsOneWidget);
    });

    testWidgets('shows loading state on button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginView(
              isLoading: true,
              onStartLogin: () async {},
              onSubmitCode: (code) async => true,
            ),
          ),
        ),
      );

      expect(find.text('로그인 중...'), findsOneWidget);
    });

    testWidgets('displays error message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginView(
              isLoading: false,
              error: '로그인 실패',
              onStartLogin: () async {},
              onSubmitCode: (code) async => true,
            ),
          ),
        ),
      );

      expect(find.text('로그인 실패'), findsOneWidget);
    });
  });

  group('AppConfig', () {
    test('default values', () {
      const config = AppConfig();
      expect(config.refreshIntervalSeconds, 60);
      expect(config.showFiveHour, true);
      expect(config.showSevenDay, true);
      expect(config.showSonnet, true);
    });

    test('copyWith creates new instance', () {
      const config = AppConfig();
      final updated = config.copyWith(refreshIntervalSeconds: 120);
      expect(updated.refreshIntervalSeconds, 120);
      expect(config.refreshIntervalSeconds, 60);
    });
  });
}
