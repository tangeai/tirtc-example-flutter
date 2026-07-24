import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_flutter/tirtc_flutter.dart';

void main() {
  testWidgets('stress local audio input lifecycle surface case', (WidgetTester tester) async {
    const int tirtcErrorNotBound = 6029;
    final input = TiRtcAudioInput();

    expect(input.state, TiRtcInputState.idle);
    expect(input.start(), completion(tirtcErrorNotBound));
    expect(input.stop(), completion(0));
    await input.dispose();
    await input.dispose();
  });
}
