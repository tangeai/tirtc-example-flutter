import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_flutter/tirtc_flutter.dart';

void main() {
  testWidgets('performance local audio input wiring case', (WidgetTester tester) async {
    const options = TiRtcAudioInputOptions();

    expect(TiRtcAudioCodec.values, const [
      TiRtcAudioCodec.g711a,
      TiRtcAudioCodec.aac,
      TiRtcAudioCodec.pcm,
      TiRtcAudioCodec.opus,
      TiRtcAudioCodec.amr,
    ]);
    expect(TiRtcAudioChannelCount.values, const [TiRtcAudioChannelCount.mono]);
    expect(options.codec, TiRtcAudioCodec.g711a);
    expect(options.sampleRate, TiRtcAudioSampleRate.rate16k);
    expect(options.channels, TiRtcAudioChannelCount.mono);
    expect(options.aecMode, TiRtcAudioAecMode.disabled);
    expect(options.agcLevel, TiRtcAudioAgcLevel.disabled);
    expect(options.ansLevel, TiRtcAudioAnsLevel.disabled);
  });
}
