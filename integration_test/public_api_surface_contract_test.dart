import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_flutter/tirtc_flutter.dart';
import 'package:tirtc_flutter/src/internal/runtime_bridge.dart';

void main() {
  test('connect link mode public enum maps to explicit native values', () {
    final TiRtcRuntimeBridge bridge = TiRtcRuntimeBridge.instance;
    final List<int> observedModes = <int>[];
    bridge.setConnectLinkModeProviderForTesting((int mode) {
      observedModes.add(mode);
      return 7000 + mode;
    });
    addTearDown(() {
      bridge.setConnectLinkModeProviderForTesting(null);
    });

    expect(TiRtc.setConnectLinkMode(TiRtcConnectLinkMode.automatic), 7000);
    expect(TiRtc.setConnectLinkMode(TiRtcConnectLinkMode.directOnly), 7001);
    expect(TiRtc.setConnectLinkMode(TiRtcConnectLinkMode.relayOnly), 7002);
    expect(observedModes, <int>[0, 1, 2]);
  });

  test('public error helpers and logging levels are callable', () {
    final TiRtcRuntimeBridge bridge = TiRtcRuntimeBridge.instance;
    bridge.allowNativeLoadFailureForTesting(enabled: true);
    bridge.forceNativeDisabledForTesting(enabled: true);
    addTearDown(() {
      bridge.forceNativeDisabledForTesting(enabled: false);
      bridge.allowNativeLoadFailureForTesting(enabled: false);
    });

    expect(TiRtc.errorToString(kTiRtcErrorOk), 'OK');
    expect(TiRtc.formatError(kTiRtcErrorOk), 'error OK (0)');
    expect(TiRtc.errorToString(kTiRtcHostErrorObjectReleased), 'TIRTC_HOST_ERROR_OBJECT_RELEASED');

    expect(() => TiRtcLogging.d('public_api_test', 'debug'), returnsNormally);
    expect(() => TiRtcLogging.i('public_api_test', 'info'), returnsNormally);
    expect(() => TiRtcLogging.w('public_api_test', 'warn'), returnsNormally);
    expect(() => TiRtcLogging.e('public_api_test', 'error'), returnsNormally);

    const TiRtcAudioOutputOptions audioOptions = TiRtcAudioOutputOptions(
      agcLevel: TiRtcAudioAgcLevel.medium,
      ansLevel: TiRtcAudioAnsLevel.high,
      bufferStrategy: TiRtcOutputBufferStrategy.noBuffer,
    );
    expect(audioOptions.agcLevel, TiRtcAudioAgcLevel.medium);
    expect(audioOptions.ansLevel, TiRtcAudioAnsLevel.high);
    expect(audioOptions.bufferStrategy, TiRtcOutputBufferStrategy.noBuffer);
    expect(audioOptions.maxBufferWatermarkMs, isNull);

    const TiRtcVideoOutputOptions videoOptions = TiRtcVideoOutputOptions(
      decoderPreference: TiRtcVideoDecoderPreference.hardware,
      bufferStrategy: TiRtcOutputBufferStrategy.automatic,
      maxBufferWatermarkMs: 120,
    );
    expect(videoOptions.decoderPreference, TiRtcVideoDecoderPreference.hardware);
    expect(videoOptions.bufferStrategy, TiRtcOutputBufferStrategy.automatic);
    expect(videoOptions.maxBufferWatermarkMs, 120);
  });

  test('public connection subscription APIs return stable fallback codes', () {
    final Directory logRoot = Directory.systemTemp.createTempSync('tirtc-public-api-surface-');
    final TiRtcRuntimeBridge bridge = TiRtcRuntimeBridge.instance;
    bridge.allowNativeLoadFailureForTesting(enabled: true);
    bridge.forceNativeDisabledForTesting(enabled: true);
    addTearDown(() {
      bridge.forceNativeDisabledForTesting(enabled: false);
      bridge.allowNativeLoadFailureForTesting(enabled: false);
      if (logRoot.existsSync()) {
        logRoot.deleteSync(recursive: true);
      }
    });

    expect(
      bridge.initialize(
        appId: '',
        endpoint: '',
        consoleLogEnabled: false,
        logRootDir: logRoot.path,
      ),
      kTiRtcErrorOk,
    );

    final TiRtcConn connection = TiRtcConn();
    final TiRtcAudioOutput audioOutput = TiRtcAudioOutput();
    final List<int> observedVolumes = <int>[];
    bridge.setAudioOutputVolumeProviderForTesting((int outputHandle, int volumePercent) {
      observedVolumes.add(volumePercent);
      return kTiRtcErrorOk;
    });
    addTearDown(() {
      bridge.setAudioOutputVolumeProviderForTesting(null);
      connection.dispose();
      audioOutput.dispose();
      expect(bridge.shutdown(), kTiRtcErrorOk);
    });

    expect(connection.subscribeVideo(streamId: 11), kTiRtcErrorOk);
    expect(connection.unsubscribeVideo(streamId: 11), kTiRtcErrorOk);
    expect(connection.subscribeAudio(streamId: 10), kTiRtcErrorOk);
    expect(connection.unsubscribeAudio(streamId: 10), kTiRtcErrorOk);
    expect(connection.requestKeyFrame(streamId: 11), kTiRtcErrorOk);

    expect(
      audioOutput.configure(
        const TiRtcAudioOutputOptions(
          agcLevel: TiRtcAudioAgcLevel.medium,
          ansLevel: TiRtcAudioAnsLevel.high,
          bufferStrategy: TiRtcOutputBufferStrategy.automatic,
          maxBufferWatermarkMs: 120,
        ),
      ),
      kTiRtcErrorOk,
    );
    expect(audioOutput.setVolume(0), kTiRtcErrorOk);
    expect(audioOutput.setVolume(100), kTiRtcErrorOk);
    expect(observedVolumes, <int>[0, 100]);
    expect(audioOutput.setVolume(-1), kTiRtcErrorInvalidArgument);
    expect(audioOutput.setVolume(101), kTiRtcErrorInvalidArgument);

    connection.dispose();
    expect(connection.requestKeyFrame(streamId: 11), kTiRtcHostErrorObjectReleased);
    audioOutput.dispose();
    expect(audioOutput.setVolume(100), kTiRtcHostErrorObjectReleased);
  });
}
