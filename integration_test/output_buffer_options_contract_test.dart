import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_flutter/tirtc_flutter.dart' show TiRtcAudioOutput, TiRtcVideoOutput;
import 'package:tirtc_flutter/src/internal/native_api.dart';
import 'package:tirtc_flutter/src/internal/runtime_bridge.dart';
import 'package:tirtc_flutter/src/public/output_buffer_strategy.dart';

TiRtcAudioOutputOptionsValue _audioOptions(
  TiRtcOutputBufferStrategy strategy,
  int? maxWatermarkMs,
) {
  return TiRtcAudioOutputOptionsValue(
    agcLevel: 0,
    ansLevel: 0,
    bufferStrategy: strategy,
    maxBufferWatermarkMs: maxWatermarkMs,
  );
}

TiRtcVideoOutputOptionsValue _videoOptions(
  TiRtcOutputBufferStrategy strategy,
  int? maxWatermarkMs,
) {
  return TiRtcVideoOutputOptionsValue(
    decoderPreference: 0,
    bufferStrategy: strategy,
    maxBufferWatermarkMs: maxWatermarkMs,
  );
}

void _expectEncodedOptions(
  TiRtcOutputBufferStrategy strategy,
  int? maxWatermarkMs, {
  required int expectedStrategy,
  required int expectedHasMax,
  required int expectedMax,
}) {
  final encoded = tiRtcEncodeOutputBufferOptionsForTesting(strategy, maxWatermarkMs);
  expect(encoded.strategy, expectedStrategy);
  expect(encoded.hasMaxBufferWatermarkMs, expectedHasMax);
  expect(encoded.maxBufferWatermarkMs, expectedMax);
}

void _expectAudioOptionsResult(
  TiRtcRuntimeBridge bridge,
  int outputHandle,
  TiRtcOutputBufferStrategy strategy,
  int? maxWatermarkMs,
  int expectedCode,
) {
  final int code = bridge.updateAudioOutputOptions(
    outputHandle: outputHandle,
    options: _audioOptions(strategy, maxWatermarkMs),
  );
  expect(code, expectedCode);
}

void _expectVideoOptionsResult(
  TiRtcRuntimeBridge bridge,
  int outputHandle,
  TiRtcOutputBufferStrategy strategy,
  int? maxWatermarkMs,
  int expectedCode,
) {
  final int code = bridge.setVideoOutputOptions(
    outputHandle: outputHandle,
    options: _videoOptions(strategy, maxWatermarkMs),
  );
  expect(code, expectedCode);
}

void main() {
  test('output buffer options validate and map through the Flutter bridge', () {
    expect(tiRtcIsValidOutputBufferOptions(TiRtcOutputBufferStrategy.automatic, null), isTrue);
    expect(tiRtcIsValidOutputBufferOptions(TiRtcOutputBufferStrategy.automatic, 1), isTrue);
    expect(tiRtcIsValidOutputBufferOptions(TiRtcOutputBufferStrategy.automatic, 0), isFalse);
    expect(tiRtcIsValidOutputBufferOptions(TiRtcOutputBufferStrategy.automatic, -1), isFalse);
    expect(tiRtcIsValidOutputBufferOptions(TiRtcOutputBufferStrategy.noBuffer, null), isTrue);
    expect(tiRtcIsValidOutputBufferOptions(TiRtcOutputBufferStrategy.noBuffer, 1), isFalse);
    expect(tiRtcIsValidOutputBufferOptions(TiRtcOutputBufferStrategy.noBuffer, 0), isFalse);

    _expectEncodedOptions(
      TiRtcOutputBufferStrategy.automatic,
      null,
      expectedStrategy: kTiRtcOutputBufferStrategyAutomatic,
      expectedHasMax: 0,
      expectedMax: 0,
    );
    _expectEncodedOptions(
      TiRtcOutputBufferStrategy.automatic,
      120,
      expectedStrategy: kTiRtcOutputBufferStrategyAutomatic,
      expectedHasMax: 1,
      expectedMax: 120,
    );
    _expectEncodedOptions(
      TiRtcOutputBufferStrategy.noBuffer,
      null,
      expectedStrategy: kTiRtcOutputBufferStrategyNoBuffer,
      expectedHasMax: 0,
      expectedMax: 0,
    );

    final Directory logRoot = Directory.systemTemp.createTempSync('tirtc-output-buffer-guard-');
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

    final TiRtcCreateHandleResult audio = bridge.createAudioOutput();
    final TiRtcCreateHandleResult video = bridge.createVideoOutput();
    final TiRtcCreateHandleResult conn = bridge.createConnection();
    expect(audio.code, kTiRtcErrorOk);
    expect(video.code, kTiRtcErrorOk);
    expect(conn.code, kTiRtcErrorOk);
    expect(audio.handle, isNot(0));
    expect(video.handle, isNot(0));
    expect(conn.handle, isNot(0));

    _expectAudioOptionsResult(bridge, audio.handle, TiRtcOutputBufferStrategy.automatic, null, kTiRtcErrorOk);
    _expectAudioOptionsResult(bridge, audio.handle, TiRtcOutputBufferStrategy.automatic, 120, kTiRtcErrorOk);
    _expectAudioOptionsResult(bridge, audio.handle, TiRtcOutputBufferStrategy.noBuffer, null, kTiRtcErrorOk);
    _expectAudioOptionsResult(bridge, audio.handle, TiRtcOutputBufferStrategy.noBuffer, 1, kTiRtcErrorInvalidArgument);
    _expectAudioOptionsResult(bridge, audio.handle, TiRtcOutputBufferStrategy.automatic, 0, kTiRtcErrorInvalidArgument);
    _expectAudioOptionsResult(
        bridge, audio.handle, TiRtcOutputBufferStrategy.automatic, -1, kTiRtcErrorInvalidArgument);

    _expectVideoOptionsResult(bridge, video.handle, TiRtcOutputBufferStrategy.automatic, null, kTiRtcErrorOk);
    _expectVideoOptionsResult(bridge, video.handle, TiRtcOutputBufferStrategy.automatic, 120, kTiRtcErrorOk);
    _expectVideoOptionsResult(bridge, video.handle, TiRtcOutputBufferStrategy.noBuffer, null, kTiRtcErrorOk);
    _expectVideoOptionsResult(bridge, video.handle, TiRtcOutputBufferStrategy.noBuffer, 1, kTiRtcErrorInvalidArgument);
    _expectVideoOptionsResult(bridge, video.handle, TiRtcOutputBufferStrategy.automatic, 0, kTiRtcErrorInvalidArgument);
    _expectVideoOptionsResult(
        bridge, video.handle, TiRtcOutputBufferStrategy.automatic, -1, kTiRtcErrorInvalidArgument);

    expect(bridge.connect(handle: conn.handle, remoteId: 'remote', token: 'token'), kTiRtcErrorOk);
    expect(
      bridge.attachAudioOutput(outputHandle: audio.handle, connectionHandle: conn.handle, streamId: 10),
      kTiRtcErrorOk,
    );
    expect(
      bridge.attachVideoOutput(outputHandle: video.handle, connectionHandle: conn.handle, streamId: 11),
      kTiRtcErrorOk,
    );
    _expectAudioOptionsResult(bridge, audio.handle, TiRtcOutputBufferStrategy.automatic, null, kTiRtcErrorInUse);
    _expectVideoOptionsResult(bridge, video.handle, TiRtcOutputBufferStrategy.automatic, null, kTiRtcErrorInUse);

    bridge.detachAudioOutput(outputHandle: audio.handle);
    bridge.detachVideoOutput(outputHandle: video.handle);
    bridge.destroyAudioOutput(outputHandle: audio.handle);
    bridge.destroyVideoOutput(outputHandle: video.handle);
    bridge.destroyConnection(handle: conn.handle);
    expect(bridge.shutdown(), kTiRtcErrorOk);
  });

  test('reset metrics session returns codes without output error callbacks', () async {
    final Directory logRoot = Directory.systemTemp.createTempSync('tirtc-output-reset-guard-');
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

    final TiRtcAudioOutput audioOutput = TiRtcAudioOutput();
    final TiRtcVideoOutput videoOutput = TiRtcVideoOutput();
    var audioErrors = 0;
    var videoErrors = 0;
    audioOutput.onError = (_) {
      audioErrors += 1;
    };
    videoOutput.onError = (_) {
      videoErrors += 1;
    };

    expect(audioOutput.resetMetricsSession(), kTiRtcHostErrorNativeLibraryUnavailable);
    expect(videoOutput.resetMetricsSession(), kTiRtcHostErrorNativeLibraryUnavailable);
    expect(audioErrors, 0);
    expect(videoErrors, 0);

    audioOutput.dispose();
    videoOutput.dispose();
    expect(audioOutput.resetMetricsSession(), kTiRtcHostErrorObjectReleased);
    expect(videoOutput.resetMetricsSession(), kTiRtcHostErrorObjectReleased);
    expect(audioErrors, 0);
    expect(videoErrors, 0);

    await Future<void>.delayed(Duration.zero);
    expect(bridge.shutdown(), kTiRtcErrorOk);
  });
}
