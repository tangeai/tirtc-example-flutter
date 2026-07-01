import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';
import 'package:tirtc_av_kit/src/internal/runtime_bridge.dart';

void main() {
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
      volumePercent: 42,
      agcLevel: 2,
      ansLevel: 3,
      bufferStrategy: TiRtcOutputBufferStrategy.noBuffer,
    );
    expect(audioOptions.volumePercent, 42);
    expect(audioOptions.agcLevel, 2);
    expect(audioOptions.ansLevel, 3);
    expect(audioOptions.bufferStrategy, TiRtcOutputBufferStrategy.noBuffer);
    expect(audioOptions.maxBufferWatermarkMs, isNull);
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
    addTearDown(() {
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
          volumePercent: 42,
          agcLevel: 2,
          ansLevel: 3,
          bufferStrategy: TiRtcOutputBufferStrategy.automatic,
          maxBufferWatermarkMs: 120,
        ),
      ),
      kTiRtcErrorOk,
    );

    connection.dispose();
    expect(connection.requestKeyFrame(streamId: 11), kTiRtcHostErrorObjectReleased);
  });
}
