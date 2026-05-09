import 'package:flutter/material.dart';

import '../demo_configuration.dart';
import '../widgets/qr_scanner_page_widgets.dart';

class DemoQrScannerPage extends StatelessWidget {
  const DemoQrScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoQrScannerPayloadPage<DemoScanPayload>(
      leadText: '将二维码完整放入方框内，系统会自动识别并填充 app_id、remote_id、token，并在提供时回填 endpoint。',
      guideText: '使用 JSON，并至少包含 `app_id`、`remote_id` 和 `token`。`endpoint` 可选，提供时会一起回填配置页。',
      samplePayloadText: '{\n'
          '  "app_id": "flutter-example-app",\n'
          '  "remote_id": "TESTTIRTC01",\n'
          '  "token": "v1.eyJzxxx",\n'
          '  "endpoint": "https://xxx.com"\n'
          '}\n\n'
          '// endpoint 也可以整个字段省略\n'
          '{\n'
          '  "app_id": "flutter-example-app",\n'
          '  "remote_id": "TESTTIRTC01",\n'
          '  "token": "v1.eyJzxxx"\n'
          '}',
      parsePayload: DemoScanPayload.tryParse,
    );
  }
}
