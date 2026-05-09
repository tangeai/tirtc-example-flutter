import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tirtc_av_kit_example/src/app_theme.dart';
import 'package:tirtc_av_kit_example/src/demo_route_lifecycle.dart';
import 'package:tirtc_av_kit_example/src/pages/configure_page.dart';

import 'src/av_contract_page.dart';
import 'src/av_contract_payload.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cli device to Flutter client AV contract', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        title: 'Ti RTC AV Integration',
        debugShowCheckedModeBanner: false,
        theme: ExampleTheme.build(),
        navigatorObservers: <NavigatorObserver>[exampleRouteObserver],
        home: AutomationPage(parseResult: AutomationPayload.fromEnvironment()),
      ),
    );
    await tester.pumpAndSettle();
    await _waitForConfigureReturn(tester);
  });
}

Future<void> _waitForConfigureReturn(WidgetTester tester) async {
  for (int second = 0; second < 220; second += 1) {
    await tester.pump(const Duration(seconds: 1));
    if (find.byType(DemoConfigurePage).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('AV integration test did not return to configure page');
}
