import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_av_kit_example/src/app_theme.dart';
import 'package:tirtc_av_kit_example/src/demo_configuration.dart';
import 'package:tirtc_av_kit_example/src/demo_widget_keys.dart';
import 'package:tirtc_av_kit_example/src/pages/configure_page.dart';

void main() {
  test('token issuer address supports fixed token path and direct token URLs', () {
    expect(normalizeDemoTokenIssuerBaseUrl('http://127.0.0.1:8966'), 'http://127.0.0.1:8966');
    expect(normalizeDemoTokenIssuerBaseUrl('http://127.0.0.1:8966/v1/tokens'), 'http://127.0.0.1:8966');
    expect(
      demoTokenIssuerTokenUri('http://127.0.0.1:8966').toString(),
      'http://127.0.0.1:8966/v1/tokens',
    );
    expect(
      normalizeDemoTokenIssuerBaseUrl('http://openapidemo.tange365.com/tirtc/token/Ue4rIG'),
      'http://openapidemo.tange365.com/tirtc/token/Ue4rIG',
    );
    expect(
      demoTokenIssuerTokenUri('http://openapidemo.tange365.com/tirtc/token/Ue4rIG').toString(),
      'http://openapidemo.tange365.com/tirtc/token/Ue4rIG',
    );
    expect(
      normalizeDemoTokenIssuerBaseUrl('http://openapidemo.tange365.com/tirtc/token?code=Ue4rIG'),
      'http://openapidemo.tange365.com/tirtc/token?code=Ue4rIG',
    );
    expect(() => normalizeDemoTokenIssuerBaseUrl('ftp://127.0.0.1:8966'), throwsFormatException);
    expect(() => normalizeDemoTokenIssuerBaseUrl('http://user:pass@127.0.0.1:8966'), throwsFormatException);
    expect(() => normalizeDemoTokenIssuerBaseUrl('http://127.0.0.1:8966/custom#fragment'), throwsFormatException);
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

  test('token acquirer requests the selected source only', () async {
    final List<DemoTokenHttpRequest> requests = <DemoTokenHttpRequest>[];
    int postCount = 0;
    final DemoTokenAcquirer acquirer = DemoTokenAcquirer(
      httpClient: (DemoTokenHttpRequest request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return const DemoTokenHttpResponse(statusCode: 200, body: 'v1.direct-token');
        }
        postCount += 1;
        if (postCount == 1) {
          return const DemoTokenHttpResponse(statusCode: 200, body: '{"token":"v1.issuer-json-token"}');
        }
        return const DemoTokenHttpResponse(statusCode: 200, body: 'v1.issuer-plain-token');
      },
    );

    final String issuerJsonToken = await acquirer.resolve(
      configuration: const DemoTokenSourceConfiguration(
        source: DemoTokenSource.issuer,
        tokenIssuerBaseUrl: 'http://127.0.0.1:8966',
        oneTimeToken: '',
      ),
      remoteId: 'device-1',
    );
    expect(issuerJsonToken, 'v1.issuer-json-token');
    expect(requests.single.method, 'POST');
    expect(requests.single.uri.toString(), 'http://127.0.0.1:8966/v1/tokens');
    expect(requests.single.jsonBody, <String, String>{'remote_id': 'device-1'});

    requests.clear();
    final String issuerPlainToken = await acquirer.resolve(
      configuration: const DemoTokenSourceConfiguration(
        source: DemoTokenSource.issuer,
        tokenIssuerBaseUrl: 'http://127.0.0.1:8966/v1/tokens',
        oneTimeToken: '',
      ),
      remoteId: 'device-1',
    );
    expect(issuerPlainToken, 'v1.issuer-plain-token');
    expect(requests.single.method, 'POST');
    expect(requests.single.uri.toString(), 'http://127.0.0.1:8966/v1/tokens');
    expect(requests.single.jsonBody, <String, String>{'remote_id': 'device-1'});

    requests.clear();
    final String directToken = await acquirer.resolve(
      configuration: const DemoTokenSourceConfiguration(
        source: DemoTokenSource.issuer,
        tokenIssuerBaseUrl: 'http://openapidemo.tange365.com/tirtc/token/Ue4rIG',
        oneTimeToken: '',
      ),
      remoteId: 'device-1',
    );
    expect(directToken, 'v1.direct-token');
    expect(requests.single.method, 'GET');
    expect(requests.single.uri.toString(), 'http://openapidemo.tange365.com/tirtc/token/Ue4rIG');
    expect(requests.single.jsonBody, isNull);

    requests.clear();
    final String oneTimeToken = await acquirer.resolve(
      configuration: const DemoTokenSourceConfiguration(
        source: DemoTokenSource.oneTime,
        tokenIssuerBaseUrl: '',
        oneTimeToken: 'v1.one-time-token',
      ),
      remoteId: 'device-1',
    );
    expect(oneTimeToken, 'v1.one-time-token');
    expect(requests, isEmpty);
  });

  testWidgets('configure page presents the two downlink token sources', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ExampleTheme.build(),
        home: const DemoConfigurePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('连接 Token'), findsOneWidget);
    expect(find.text('Token 签发服务地址'), findsWidgets);
    expect(find.text('一次性连接 Token'), findsWidgets);
    expect(find.byKey(DemoWidgetKeys.tokenSourceIssuerButton), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.tokenSourceOneTimeButton), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.tokenIssuerBaseUrlField), findsOneWidget);
    await tester.tap(find.byKey(DemoWidgetKeys.tokenSourceOneTimeButton));
    await tester.pumpAndSettle();
    expect(find.byKey(DemoWidgetKeys.tokenField), findsOneWidget);
    expect(find.text('token_issuer_base_url'), findsNothing);
  });
}
