import 'package:flutter/material.dart';

import '../demo_configuration.dart';
import '../widgets/qr_scanner_page_widgets.dart';

class DemoQrScannerPage extends StatelessWidget {
  const DemoQrScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoQrScannerPayloadPage<DemoScanPayload>(
      leadText: '将 TiRTC DevTools CLI 生成的二维码完整放入方框内，系统会自动填充一次性连接 Token。',
      guideText: '二维码可以是包含 app_id、remote_id、token 和可选 endpoint 的 JSON，也可以是纯 v1 Token。',
      samplePayloadText: '{\n'
          '  "app_id": "flutter-example-app",\n'
          '  "remote_id": "TESTTIRTC01",\n'
          '  "token": "v1.eyJzxxx",\n'
          '  "endpoint": "https://xxx.com"\n'
          '}\n\n'
          '// 或只提供一次性连接 Token\n'
          'v1.eyJzxxx',
      parsePayload: DemoScanPayload.tryParse,
    );
  }
}
