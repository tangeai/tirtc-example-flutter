import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_flutter/tirtc_flutter.dart';

void main() {
  testWidgets('stability local audio input wiring case', (WidgetTester tester) async {
    const options = TiRtcAudioInputOptions(
      codec: TiRtcAudioCodec.aac,
      sampleRate: TiRtcAudioSampleRate.rate8k,
      channels: TiRtcAudioChannelCount.mono,
      aecMode: TiRtcAudioAecMode.enabled,
      agcLevel: TiRtcAudioAgcLevel.medium,
      ansLevel: TiRtcAudioAnsLevel.high,
    );

    expect(options.codec, TiRtcAudioCodec.aac);
    expect(options.sampleRate, TiRtcAudioSampleRate.rate8k);
    expect(options.channels, TiRtcAudioChannelCount.mono);
    expect(options.aecMode, TiRtcAudioAecMode.enabled);
    expect(options.agcLevel, TiRtcAudioAgcLevel.medium);
    expect(options.ansLevel, TiRtcAudioAnsLevel.high);
  });
}
