import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

void main() {
  testWidgets('performance local audio input wiring case', (WidgetTester tester) async {
    const options = TiRtcAudioInputOptions();

    expect(TiRtcAudioCodec.values, const [
      TiRtcAudioCodec.g711a,
      TiRtcAudioCodec.aac,
      TiRtcAudioCodec.pcm,
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
