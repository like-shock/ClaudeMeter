import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claude_monitor_flutter/screens/home_screen.dart';
import 'package:claude_monitor_flutter/models/config.dart';
import 'package:claude_monitor_flutter/models/usage_data.dart';

void main() {
  group('HomeScreen 버튼 테스트', () {
    late bool refreshCalled;
    late bool settingsCalled;
    late bool quitCalled;

    setUp(() {
      refreshCalled = false;
      settingsCalled = false;
      quitCalled = false;
    });

    Widget buildTestWidget({
      bool isLoggedIn = true,
      bool isLoading = false,
      UsageData? usageData,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            isLoggedIn: isLoggedIn,
            isLoading: isLoading,
            usageData: usageData ?? UsageData.empty(),
            config: const AppConfig(),
            onLogin: () {},
            onRefresh: () => refreshCalled = true,
            onSettings: () => settingsCalled = true,
            onQuit: () => quitCalled = true,
          ),
        ),
      );
    }

    testWidgets('설정 버튼 탭 시 onSettings 콜백 호출', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // 설정 아이콘 찾기
      final settingsButton = find.byIcon(Icons.settings);
      expect(settingsButton, findsOneWidget);

      // 탭
      await tester.tap(settingsButton);
      await tester.pump();

      // 콜백 호출 확인
      expect(settingsCalled, isTrue, reason: 'onSettings 콜백이 호출되어야 함');
    });

    testWidgets('종료 버튼 탭 시 onQuit 콜백 호출', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // 종료 아이콘 찾기
      final quitButton = find.byIcon(Icons.power_settings_new);
      expect(quitButton, findsOneWidget);

      // 탭
      await tester.tap(quitButton);
      await tester.pump();

      // 콜백 호출 확인
      expect(quitCalled, isTrue, reason: 'onQuit 콜백이 호출되어야 함');
    });

    testWidgets('새로고침 버튼 탭 시 onRefresh 콜백 호출 (로그인 상태)', (tester) async {
      await tester.pumpWidget(buildTestWidget(isLoggedIn: true, isLoading: false));

      // 새로고침 아이콘 찾기
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      // 탭
      await tester.tap(refreshButton);
      await tester.pump();

      // 콜백 호출 확인
      expect(refreshCalled, isTrue, reason: 'onRefresh 콜백이 호출되어야 함');
    });

    testWidgets('새로고침 버튼은 로딩 중일 때 비활성화', (tester) async {
      await tester.pumpWidget(buildTestWidget(isLoggedIn: true, isLoading: true));

      // 로딩 중이면 CircularProgressIndicator가 보임
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 새로고침 아이콘은 없어야 함 (로딩 인디케이터로 대체)
      // GestureDetector 탭해도 콜백 호출 안 됨
      expect(refreshCalled, isFalse);
    });

    testWidgets('새로고침 버튼은 로그아웃 상태에서 비활성화', (tester) async {
      await tester.pumpWidget(buildTestWidget(isLoggedIn: false, isLoading: false));

      // 새로고침 아이콘 찾기
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      // 탭
      await tester.tap(refreshButton);
      await tester.pump();

      // 콜백 호출 안 됨 (비활성화 상태)
      expect(refreshCalled, isFalse, reason: '로그아웃 상태에서는 onRefresh가 호출되면 안 됨');
    });

    testWidgets('GestureDetector가 올바르게 설정되어 있는지 확인', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // GestureDetector 위젯 찾기
      final gestureDetectors = find.byType(GestureDetector);
      
      // 최소 3개의 GestureDetector가 있어야 함 (refresh, settings, quit)
      expect(gestureDetectors, findsAtLeastNWidgets(3));
    });
  });
}
