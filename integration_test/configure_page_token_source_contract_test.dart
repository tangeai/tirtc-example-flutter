import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_example/src/app_theme.dart';
import 'package:tirtc_example/src/demo_configuration.dart';
import 'package:tirtc_example/src/demo_widget_keys.dart';
import 'package:tirtc_example/src/pages/configure_page.dart';

void main() {
  test('token acquirer accepts one-time tokens only', () async {
    const DemoTokenAcquirer acquirer = DemoTokenAcquirer();

    expect(await acquirer.resolve(token: '  v1.one-time-token  '), 'v1.one-time-token');
    expect(() => acquirer.resolve(token: 'http://127.0.0.1:8966/v1/tokens'), throwsFormatException);
  });

  test('QR parser accepts current CLI JSON and pure token payloads', () {
    final DemoScanPayload? cliPayload = DemoScanPayload.tryParse(
      '{"app_id":"app-1","remote_id":"device-1","token":"v1.cli-token","endpoint":"https://endpoint.invalid"}',
    );
    expect(cliPayload, isNotNull);
    expect(cliPayload!.appId, 'app-1');
    expect(cliPayload.remoteId, 'device-1');
    expect(cliPayload.token, 'v1.cli-token');
    expect(cliPayload.endpoint, 'https://endpoint.invalid');

    final DemoScanPayload? tokenPayload = DemoScanPayload.tryParse('v1.manual-token');
    expect(tokenPayload, isNotNull);
    expect(tokenPayload!.token, 'v1.manual-token');
    expect(tokenPayload.appId, isNull);
    expect(tokenPayload.remoteId, isNull);
    expect(tokenPayload.endpoint, isNull);
  });

  test('QR parser rejects legacy and issuer URL payloads', () {
    expect(
      DemoScanPayload.tryParse('{"peer_id":"device-1","service_entry":"https://endpoint.invalid","token":"v1.token"}'),
      isNull,
    );
    expect(
      DemoScanPayload.tryParse(
        '{"app_id":"app-1","remote_id":"device-1","token":"v1.token",'
        '"token_issuer_url":"http://127.0.0.1:8966/v1/tokens"}',
      ),
      isNull,
    );
  });

  testWidgets('configure page presents one-time token input and scan button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ExampleTheme.build(),
        home: const DemoConfigurePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ti RTC'), findsOneWidget);
    expect(find.text('Based on Flutter'), findsOneWidget);
    expect(find.text('连接 Token'), findsNothing);
    expect(find.text('Token 签发服务地址'), findsNothing);
    expect(find.text('一次性连接 Token'), findsWidgets);
    expect(find.text('粘贴 v1.xxx 一次性 Token，或点右侧扫码。'), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.tokenField), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.tokenScanButton), findsOneWidget);
    expect(find.text('扫码'), findsOneWidget);
    expect(find.text('开始连接、拉流播放'), findsOneWidget);
    expect(find.text('token_issuer_base_url'), findsNothing);

    final Offset endpointTopLeft = tester.getTopLeft(find.byKey(DemoWidgetKeys.endpointField));
    final Offset appIdTopLeft = tester.getTopLeft(find.byKey(DemoWidgetKeys.appIdField));
    final Offset endpointBottomLeft = tester.getBottomLeft(find.byKey(DemoWidgetKeys.endpointField));
    expect(endpointTopLeft.dx, appIdTopLeft.dx);
    expect(appIdTopLeft.dy, greaterThan(endpointBottomLeft.dy));
  });
}
