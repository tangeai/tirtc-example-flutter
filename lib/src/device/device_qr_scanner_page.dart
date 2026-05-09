import 'package:flutter/material.dart';

import '../demo_configuration.dart';
import '../widgets/qr_scanner_page_widgets.dart';

class DemoDeviceQrScannerPage extends StatelessWidget {
  const DemoDeviceQrScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoQrScannerPayloadPage<DemoDeviceServerScanPayload>(
      leadText: '将二维码完整放入方框内，系统会自动识别并填充 device_id、device_secret_key，并在提供时回填 endpoint。',
      guideText: '使用 JSON，并且只包含 `device_id`、`device_secret_key`，以及可选的 `endpoint`。',
      samplePayloadText: '{\n'
          '  "device_id": "TESTTIRTC01",\n'
          '  "device_secret_key": "secret",\n'
          '  "endpoint": "https://xxx.com"\n'
          '}',
      parsePayload: DemoDeviceServerScanPayload.tryParse,
    );
  }
}
