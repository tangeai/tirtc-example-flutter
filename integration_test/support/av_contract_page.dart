import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import 'package:tirtc_av_kit_example/src/app_theme.dart';
import 'package:tirtc_av_kit_example/src/demo_configuration.dart';
import 'package:tirtc_av_kit_example/src/demo_device_server_controller.dart';
import 'package:tirtc_av_kit_example/src/demo_downlink_session.dart';
import 'package:tirtc_av_kit_example/src/demo_downlink_support.dart';
import 'package:tirtc_av_kit_example/src/demo_stream_message.dart';
import 'package:tirtc_av_kit_example/src/demo_test_hooks.dart' show DemoAutomationMarkerSink;
import 'package:tirtc_av_kit_example/src/pages/configure_page.dart';
import 'package:tirtc_av_kit_example/src/settings/demo_example_settings_store.dart';
import 'package:tirtc_av_kit_example/src/widgets/notice_dialog.dart';
import 'package:tirtc_av_kit_example/src/widgets/downlink_center_loading.dart';
import 'package:tirtc_av_kit_example/src/widgets/downlink_metrics_overlay.dart';
import 'package:tirtc_av_kit_example/src/widgets/downlink_metrics_overlay_markers.dart';
import 'package:tirtc_av_kit_example/src/widgets/downlink_metrics_overlay_model.dart';
import 'package:tirtc_av_kit_example/src/widgets/player_page_widgets.dart';
import 'av_contract_command_probe.dart';
import 'av_contract_local_audio_probe.dart';
import 'av_contract_marker_sink.dart';
import 'av_contract_metrics_snapshot.dart';
import 'av_contract_payload.dart';

final class _ScenarioMarkerSink implements DemoAutomationMarkerSink {
  _ScenarioMarkerSink({
    required this.delegate,
    required this.payload,
  });

  final DemoAutomationMarkerSink delegate;
  final AutomationPayload payload;

  @override
  void passed(String marker, {Map<String, Object?> payload = const <String, Object?>{}}) {
    if (marker == 'stream_message_sent') {
      delegate.passed(marker, payload: <String, Object?>{
        'scenario': this.payload.scenario,
        'pairing_id': this.payload.pairingId,
        ...payload,
      });
      return;
    }
    delegate.passed(marker, payload: payload);
  }

  @override
  void failure({
    required String failureStage,
    required String message,
    int? errorCode,
  }) {
    delegate.failure(failureStage: failureStage, message: message, errorCode: errorCode);
  }
}

final class AutomationPage extends StatefulWidget {
  const AutomationPage({
    super.key,
    required this.parseResult,
  });

  final AutomationPayloadParseResult parseResult;

  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  static const MethodChannel _permissionChannel = MethodChannel(
    'tirtc_av_kit_example/permissions',
  );
  static const Duration _stagePollInterval = Duration(milliseconds: 100);
  static const Duration _metricsPollInterval = Duration(seconds: 1);
  static const int _runtimeObjectsLiveCode = 1007;
  static const int _automationSessionGeneration = 1;

  final DemoDownlinkAudioSession _audioSession = DemoDownlinkAudioSession();
  final DemoExampleSettingsStore _settingsStore = const DemoExampleSettingsStore();
  late final AutomationMarkerSink _markerSink;
  DemoDownlinkSession? _session;
  TiRtcConnService? _service;
  DemoDeviceServerController? _deviceServerController;
  Timer? _metricsPollTimer;
  DownlinkMetricsOverlayModel? _metricsOverlay;
  DownlinkMetricsOverlayModel? _lastAvStatsOverlay;

  bool _finished = false;
  bool _terminal = false;
  bool _videoRenderingVisible = false;
  int _audioErrorCount = 0;
  int _videoErrorCount = 0;
  bool _commandEchoMarked = false;
  bool _streamMessageMarked = false;
  Map<String, Object?>? _pendingStreamMessageMarkerPayload;
  Size? _renderSize;

  Completer<void>? _connected;
  Completer<void>? _audioPlaying;
  Completer<void>? _videoRendering;
  Completer<String>? _failure;
  AutomationCommandProbe? _commandProbe;

  @override
  void initState() {
    super.initState();
    final AutomationPayload? payload = widget.parseResult.payload;
    _markerSink = AutomationMarkerSink(
      runId: payload?.runId ?? automationRunIdDefine,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_run());
    });
  }

  @override
  void dispose() {
    _stopMetricsPolling();
    _clearCallbacks();
    unawaited(
      _releaseAutomationResources(reason: 'automation_dispose').whenComplete(_disposeSessionAsync),
    );
    super.dispose();
  }

  Future<void> _run() async {
    final AutomationPayload? payload = widget.parseResult.payload;
    if (payload == null) {
      _markerSink.failure(
        failureStage: 'payload_apply',
        message: widget.parseResult.failureMessage ?? 'automation payload invalid',
      );
      _finish();
      return;
    }

    final DemoExampleSettings settings = await _settingsStore.load(
      testVideoDecoderPreference: payload.videoDecoderPreference,
      testOutputBufferPolicy: payload.bufferPolicy,
    );
    _markerSink.passed('payload_applied', payload: payload.markerPayload());
    if (payload.scenario == AutomationPayload.scenarioFlutterDeviceServerToCliClient) {
      await _runFlutterDeviceServerToCliClient(payload, settings);
      return;
    }

    final int initializeCode = await TiRtc.initialize(
      TiRtcInitOptions(
        appId: payload.appId,
        endpoint: payload.endpoint ?? '',
        consoleLogEnabled: settings.consoleLogEnabled,
      ),
    );
    if (initializeCode != 0) {
      _fail(
        failureStage: 'runtime_init',
        message: 'runtime initialize failed',
        errorCode: initializeCode,
      );
      return;
    }
    _markerSink.passed('runtime_initialized', payload: <String, Object?>{
      'endpoint': payload.endpoint,
      'app_id_present': payload.appId.isNotEmpty,
    });

    await _runCliDeviceToFlutterClient(payload, settings);
  }

  Future<void> _runCliDeviceToFlutterClient(
    AutomationPayload payload,
    DemoExampleSettings settings,
  ) async {
    _session = DemoDownlinkSession();
    if (mounted) {
      setState(() {});
    }

    final int audioSessionCode = await _audioSession.retainIfNeeded();
    if (audioSessionCode != 0) {
      _fail(
        failureStage: 'audio_output',
        message: 'audio session retain failed',
        errorCode: audioSessionCode,
      );
      return;
    }

    _bindCallbacks();
    final int connectCode = _session!.connect(remoteId: payload.remoteId, token: payload.token);
    if (connectCode != 0) {
      _fail(
        failureStage: 'connect',
        message: 'connect failed',
        errorCode: connectCode,
      );
      return;
    }
    if (!await _waitFor(_connected!.future, failureStage: 'connect')) {
      return;
    }
    _markerSink.passed('connected', payload: <String, Object?>{
      'remote_id': payload.remoteId,
    });

    final TiRtcOutputBufferStrategy outputBufferStrategy = _outputBufferStrategy(settings);
    final int audioOptionsCode = _session!.setAudioOptions(bufferStrategy: outputBufferStrategy);
    if (audioOptionsCode != 0) {
      _fail(
        failureStage: 'audio_buffer_options',
        message: 'audio output buffer options failed',
        errorCode: audioOptionsCode,
      );
      return;
    }
    final int videoOptionsCode = _session!.setVideoOptions(
      decoderPreference: settings.videoDecoderPreference,
      bufferStrategy: outputBufferStrategy,
    );
    if (videoOptionsCode != 0) {
      _fail(
        failureStage: 'video_decoder_preference',
        message: 'video decoder preference apply failed',
        errorCode: videoOptionsCode,
      );
      return;
    }
    _markerSink.passed('buffer_policy_configured', payload: <String, Object?>{
      'scenario': payload.scenario,
      'buffer_policy': settings.outputBufferPolicy,
      'audio_strategy': _outputBufferStrategyName(outputBufferStrategy),
      'video_strategy': _outputBufferStrategyName(outputBufferStrategy),
      'audio_max_watermark_ms': null,
      'video_max_watermark_ms': null,
      'audio_configure_code': audioOptionsCode,
      'video_set_options_code': videoOptionsCode,
    });

    final int audioAttachCode = _session!.attachAudio(streamId: payload.audioStreamId);
    if (audioAttachCode != 0) {
      _fail(
        failureStage: 'audio_attach',
        message: 'audio attach failed',
        errorCode: audioAttachCode,
      );
      return;
    }
    _markerSink.passed('audio_attached', payload: <String, Object?>{
      'stream_id': payload.audioStreamId,
    });
    if (_session!.audioState == TiRtcAudioOutputState.playing) {
      _complete(_audioPlaying);
    }
    if (!await _waitFor(_audioPlaying!.future, failureStage: 'audio_output')) {
      return;
    }
    _markerSink.passed('audio_playing', payload: <String, Object?>{
      'audio_error_count': _audioErrorCount,
    });

    TiRtcLogging.i(
      'flutter_example',
      'event=example_video_attach_requested '
          'session_generation=$_automationSessionGeneration '
          'video_stream_id=${payload.videoStreamId} '
          'requested_preference=${settings.videoDecoderPreference}',
    );
    final int videoAttachCode = _session!.attachVideo(streamId: payload.videoStreamId);
    TiRtcLogging.i(
      'flutter_example',
      'event=example_video_attach_result '
          'session_generation=$_automationSessionGeneration '
          'video_stream_id=${payload.videoStreamId} '
          'requested_preference=${settings.videoDecoderPreference} '
          'code=$videoAttachCode',
    );
    if (videoAttachCode != 0) {
      _fail(
        failureStage: 'video_attach',
        message: 'video attach failed',
        errorCode: videoAttachCode,
      );
      return;
    }
    _markerSink.passed('video_attached', payload: <String, Object?>{
      'stream_id': payload.videoStreamId,
    });
    if (_session!.videoState == TiRtcVideoOutputState.rendering) {
      _complete(_videoRendering);
    }
    if (!await _waitFor(_videoRendering!.future, failureStage: 'render_timeout')) {
      return;
    }
    final TiRtcVideoOutputMetricsResult? metrics = await _waitForFirstFrameMetrics();
    if (metrics == null) {
      _fail(
        failureStage: 'render_timeout',
        message: 'first frame metrics timeout',
      );
      return;
    }
    final int? firstFrameDurationMs = metrics.snapshot?.startup.firstFrameDurationMs;
    if (metrics.code != 0 || firstFrameDurationMs == null || firstFrameDurationMs < 0) {
      _fail(
        failureStage: 'render_timeout',
        message: 'first frame metrics unavailable',
        errorCode: metrics.code,
      );
      return;
    }
    _markerSink.passed('video_rendering', payload: <String, Object?>{
      'first_frame_duration_ms': firstFrameDurationMs,
      'render_width': _renderSize?.width.round(),
      'render_height': _renderSize?.height.round(),
    });
    _setVideoRendering();
    final DownlinkMetricsOverlayModel? debugStats = await _waitForDebugStats(
      requestedDecoderPreference: settings.videoDecoderPreference,
    );
    if (debugStats == null) {
      _fail(
        failureStage: 'debug_stats',
        message: 'debug stats unavailable',
      );
      return;
    }
    _markerSink.passed(
      'debug_stats_ready',
      payload: <String, Object?>{
        ...debugStats.debugMarkerPayload(sessionGeneration: _automationSessionGeneration),
        'requested_output_buffer_policy': settings.outputBufferPolicy,
        'requested_output_buffer_max_watermark_ms': null,
        'buffer_policy_ok': true,
      },
    );
    if (!await _startAndroidTalkbackAudioIfNeeded(settings)) {
      return;
    }
    if (!await _runCommandProbe()) {
      return;
    }
    _markStreamMessageReceivedIfReady();
    _updateMetricsOverlay(debugStats);
    _startMetricsPolling(requestedDecoderPreference: settings.videoDecoderPreference);

    if (!await _runMeasurementPeriod(payload)) {
      return;
    }
    final DownlinkMetricsOverlayModel? finalDebugStats = _session!.readMetricsOverlay(
      requestedDecoderPreference: settings.videoDecoderPreference,
    );
    final DownlinkMetricsOverlayModel? markerStats = _lastAvStatsOverlay ?? finalDebugStats;
    final bool videoOutputHealthy = _session!.videoState == TiRtcVideoOutputState.rendering ||
        (payload.scenario == AutomationPayload.scenarioCliDeviceToFlutterClient &&
            _session!.videoState == TiRtcVideoOutputState.buffering &&
            _renderSize != null);
    if (_audioErrorCount != 0 ||
        _videoErrorCount != 0 ||
        !_isHealthyAudioState(_session!.audioState) ||
        !videoOutputHealthy ||
        markerStats == null ||
        !markerStats.debugStatsReady) {
      _fail(
        failureStage: 'render_window',
        message: 'render window ended with unhealthy output state',
      );
      return;
    }
    _markerSink.passed(
      'final_metrics_snapshot',
      payload: avContractFinalMetricsSnapshotPayload(payload: payload, metrics: markerStats),
    );
    _markerSink.passed('render_window_completed', payload: <String, Object?>{
      'audio_error_count': _audioErrorCount,
      'video_error_count': _videoErrorCount,
      'audio_state': _session!.audioState.name,
      'video_state': _session!.videoState.name,
      'requested_output_buffer_policy': settings.outputBufferPolicy,
      'requested_output_buffer_max_watermark_ms': null,
      'buffer_policy_ok': true,
      ...markerStats.debugMarkerPayload(sessionGeneration: _automationSessionGeneration),
    });

    int? logUploadFailureCode;
    final ({int code, String? logId}) upload = await TiRtcLogging.upload();
    if (upload.code != 0 || upload.logId == null || upload.logId!.isEmpty) {
      logUploadFailureCode = upload.code == 0 ? 1 : upload.code;
    } else {
      _markerSink.passed('log_upload_completed', payload: <String, Object?>{
        'log_id': upload.logId,
        'code': upload.code,
      });
    }

    final int teardownCode = await _runAutomationTeardown();
    if (teardownCode != 0) {
      _markFailure(
        failureStage: 'teardown',
        message: 'runtime shutdown failed',
        errorCode: teardownCode,
      );
      _finish();
      return;
    }
    if (logUploadFailureCode != null) {
      _markFailure(
        failureStage: 'log_upload',
        message: 'log upload failed',
        errorCode: logUploadFailureCode,
      );
      _finish();
      return;
    }
    _finish();
  }

  Future<bool> _runMeasurementPeriod(AutomationPayload payload) async {
    final int? resetAfterSeconds = payload.metricsSessionResetAfterSeconds;
    if (resetAfterSeconds == null) {
      await Future<void>.delayed(Duration(seconds: payload.renderWindowSeconds));
      return true;
    }
    if (resetAfterSeconds > 0) {
      await Future<void>.delayed(Duration(seconds: resetAfterSeconds));
    }
    final DemoDownlinkSession? session = _session;
    if (session == null) {
      _fail(
        failureStage: 'measurement_start',
        message: 'downlink session missing before metrics reset',
      );
      return false;
    }
    final int resetCode = session.resetOutputMetricsSession();
    if (resetCode != 0) {
      _fail(
        failureStage: 'measurement_start',
        message: 'metrics session reset failed',
        errorCode: resetCode,
      );
      return false;
    }
    _markerSink.passed('metrics_session_reset', payload: <String, Object?>{
      'after_seconds': resetAfterSeconds,
      'measurement_duration_seconds': payload.renderWindowSeconds - resetAfterSeconds,
    });
    final int remainingSeconds = payload.renderWindowSeconds - resetAfterSeconds;
    if (remainingSeconds > 0) {
      await Future<void>.delayed(Duration(seconds: remainingSeconds));
    }
    return true;
  }

  TiRtcOutputBufferStrategy _outputBufferStrategy(DemoExampleSettings settings) {
    return settings.outputBufferPolicy == DemoExampleSettings.outputBufferPolicyNoBuffer
        ? TiRtcOutputBufferStrategy.noBuffer
        : TiRtcOutputBufferStrategy.automatic;
  }

  String _outputBufferStrategyName(TiRtcOutputBufferStrategy strategy) {
    return switch (strategy) {
      TiRtcOutputBufferStrategy.noBuffer => 'NO_BUFFER',
      TiRtcOutputBufferStrategy.automatic => 'AUTOMATIC',
    };
  }

  Future<bool> _startAndroidTalkbackAudioIfNeeded(DemoExampleSettings settings) async {
    final AvContractLocalAudioProbeResult result = await startAvContractLocalAudioProbe(
      session: _session,
      settings: settings,
    );
    if (!result.ok) {
      _fail(
        failureStage: result.failureStage ?? 'local_audio_start',
        message: result.message ?? 'local audio input failed',
        errorCode: result.errorCode,
      );
      return false;
    }
    for (final AvContractLocalAudioProbeMarker marker in result.markers) {
      _markerSink.passed(marker.name, payload: marker.payload);
    }
    return true;
  }

  Future<void> _runFlutterDeviceServerToCliClient(
    AutomationPayload payload,
    DemoExampleSettings settings,
  ) async {
    final DemoDeviceServerController controller = DemoDeviceServerController(
      configuration: DemoDeviceServerConfiguration(
        endpoint: payload.endpoint ?? '',
        deviceId: payload.deviceId,
        deviceSecretKey: payload.deviceSecretKey,
        videoCodec: DemoDeviceVideoCodec.tryParse(payload.codec) ?? DemoDeviceVideoCodec.h264,
        audioCodec: DemoDeviceAudioCodec.tryParse(payload.audioCodec) ?? DemoDeviceAudioCodec.g711a,
        audioSampleRate:
            DemoDeviceAudioSampleRate.tryParseHertz(payload.audioSampleRateHz) ?? DemoDeviceAudioSampleRate.rate16k,
        audioChannels:
            DemoDeviceAudioChannelCount.tryParseCount(payload.audioChannels) ?? DemoDeviceAudioChannelCount.mono,
        encoderPreference:
            DemoDeviceEncoderPreference.tryParse(payload.encoderPreference) ?? DemoDeviceEncoderPreference.hardware,
        settings: settings,
      ),
      markerSink: _ScenarioMarkerSink(delegate: _markerSink, payload: payload),
      renderWindowSeconds: payload.renderWindowSeconds,
      requestPermissions: _requestCapturePermissionsIfNeeded,
    );
    _deviceServerController = controller;
    controller.addListener(_syncDeviceServerControllerState);
    _syncDeviceServerControllerState();
    await controller.start();
    controller.removeListener(_syncDeviceServerControllerState);
    _deviceServerController = null;
    _session = null;
    _finish();
  }

  Future<bool> _requestCapturePermissionsIfNeeded() async {
    final bool isOhos = Platform.operatingSystem == 'ohos';
    if (!Platform.isAndroid && !isOhos) {
      return true;
    }

    final String platformName = isOhos ? 'ohos' : 'android';
    final bool cameraGranted = await _requestCapturePermission(
      platformName: platformName,
      permissionName: 'camera',
      method: 'requestCameraPermission',
    );
    if (!cameraGranted) {
      return false;
    }
    return _requestCapturePermission(
      platformName: platformName,
      permissionName: 'microphone',
      method: 'requestMicrophonePermission',
    );
  }

  Future<bool> _requestCapturePermission({
    required String platformName,
    required String permissionName,
    required String method,
  }) async {
    TiRtcLogging.i('flutter_example', '${platformName}_${permissionName}_permission_request_started');
    try {
      final bool granted = await _permissionChannel.invokeMethod<bool>(method) ?? false;
      TiRtcLogging.i(
          'flutter_example', '${platformName}_${permissionName}_permission_request_finished granted=$granted');
      if (granted) {
        _markerSink.passed('${permissionName}_permission_granted', payload: <String, Object?>{
          'platform': platformName,
        });
      }
      return granted;
    } on PlatformException catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        '${platformName}_${permissionName}_permission_request_failed code=${error.code} message=${error.message ?? ''}',
      );
      return false;
    }
  }

  void _bindCallbacks() {
    _connected = Completer<void>();
    _audioPlaying = Completer<void>();
    _videoRendering = Completer<void>();
    _failure = Completer<String>();
    _session!.bindCallbacks(
      onConnectionStateChanged: (TiRtcConnState state, int errorCode) {
        if (state == TiRtcConnState.connected && errorCode == 0) {
          _complete(_connected);
        }
        if (state == TiRtcConnState.disconnected && errorCode != 0) {
          _completeFailure('connect');
        }
      },
      onAudioStateChanged: (TiRtcAudioOutputState state) {
        if (state == TiRtcAudioOutputState.playing) {
          _complete(_audioPlaying);
        }
        if (state == TiRtcAudioOutputState.failed) {
          _audioErrorCount += 1;
          _completeFailure('audio_output');
        }
      },
      onAudioError: (int code) {
        _audioErrorCount += 1;
        _completeFailure('audio_output');
      },
      onVideoStateChanged: (TiRtcVideoOutputState state) {
        if (state == TiRtcVideoOutputState.rendering) {
          _complete(_videoRendering);
        }
        if (state == TiRtcVideoOutputState.failed) {
          _videoErrorCount += 1;
          _completeFailure('render_timeout');
        }
      },
      onVideoRenderSizeChanged: (Size size) {
        _renderSize = size;
      },
      onVideoError: (int code) {
        _videoErrorCount += 1;
        _completeFailure('render_timeout');
      },
      onCommand: _handleAutomationCommand,
      onStreamMessage: _handleAutomationStreamMessage,
    );
  }

  void _handleAutomationCommand(int commandId, Uint8List payload) {
    _commandProbe?.handleCommand(commandId, payload);
  }

  void _handleAutomationStreamMessage(int streamId, int timestampMs, Uint8List payload) {
    final AutomationPayload? automationPayload = widget.parseResult.payload;
    if (automationPayload == null || streamId != automationPayload.videoStreamId) {
      return;
    }
    final int? epochSeconds = decodeDemoStreamMessageEpochSeconds(payload);
    if (epochSeconds == null) {
      return;
    }
    _pendingStreamMessageMarkerPayload = <String, Object?>{
      'scenario': automationPayload.scenario,
      'pairing_id': automationPayload.pairingId,
      'session_index': 1,
      'stream_id': streamId,
      'payload_epoch_seconds': epochSeconds,
      'payload_bytes': payload.length,
      'payload_hash': demoStreamMessagePayloadHash(payload),
      'received_count': 1,
      'matched_source': true,
    };
    _markStreamMessageReceivedIfReady();
  }

  Future<bool> _runCommandProbe() async {
    final DemoDownlinkSession? session = _session;
    if (session == null) {
      _fail(
        failureStage: 'command_echo',
        message: 'session unavailable',
      );
      return false;
    }
    final AutomationCommandProbe probe = AutomationCommandProbe();
    _commandProbe = probe;
    final AutomationCommandProbeResult result = await probe.run(
      sendCommand: session.sendCommand,
    );
    if (identical(_commandProbe, probe)) {
      _commandProbe = null;
    }
    if (!result.ok) {
      _fail(
        failureStage: 'command_echo',
        message: result.timedOut ? 'command echo timeout' : 'command send failed',
        errorCode: result.errorCode,
      );
      return false;
    }
    _markerSink.passed('command_echo_completed', payload: <String, Object?>{
      'command_id': result.commandId,
      'payload_text': result.payloadText,
      'payload_bytes': result.payloadBytes,
    });
    _commandEchoMarked = true;
    return true;
  }

  void _markStreamMessageReceivedIfReady() {
    if (_streamMessageMarked || !_commandEchoMarked) {
      return;
    }
    final Map<String, Object?>? payload = _pendingStreamMessageMarkerPayload;
    if (payload == null) {
      return;
    }
    _streamMessageMarked = true;
    _markerSink.passed('stream_message_received', payload: payload);
  }

  bool _isHealthyAudioState(TiRtcAudioOutputState state) {
    return state == TiRtcAudioOutputState.playing || state == TiRtcAudioOutputState.buffering;
  }

  Future<bool> _waitFor(Future<void> future, {required String failureStage}) async {
    final Object result = await Future.any<Object>(<Future<Object>>[
      future.then<Object>((_) => true),
      _failure!.future.then<Object>((String stage) => stage),
      Future<void>.delayed(_stagePollInterval).then<Object>((_) => false),
    ]);
    if (result == true) {
      return true;
    }
    if (result is String) {
      _fail(failureStage: result, message: '$result failed');
      return false;
    }
    return _waitFor(future, failureStage: failureStage);
  }

  Future<TiRtcVideoOutputMetricsResult?> _waitForFirstFrameMetrics() async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      if (_failure?.isCompleted ?? false) {
        return null;
      }
      final TiRtcVideoOutputMetricsResult metrics = _session!.videoMetrics();
      final int? firstFrameDurationMs = metrics.snapshot?.startup.firstFrameDurationMs;
      if (metrics.code == 0 && firstFrameDurationMs != null && firstFrameDurationMs >= 0) {
        return metrics;
      }
      await Future<void>.delayed(_stagePollInterval);
    }
    return null;
  }

  Future<DownlinkMetricsOverlayModel?> _waitForDebugStats({
    required int requestedDecoderPreference,
  }) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      if (_failure?.isCompleted ?? false) {
        return null;
      }
      final DownlinkMetricsOverlayModel? metrics = _session!.readMetricsOverlay(
        requestedDecoderPreference: requestedDecoderPreference,
      );
      if (metrics != null && metrics.debugStatsReady) {
        return metrics;
      }
      await Future<void>.delayed(_stagePollInterval);
    }
    return null;
  }

  void _complete(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _completeFailure(String stage) {
    final Completer<String>? failure = _failure;
    if (failure != null && !failure.isCompleted) {
      failure.complete(stage);
    }
  }

  void _fail({
    required String failureStage,
    required String message,
    int? errorCode,
  }) {
    if (!_markFailure(failureStage: failureStage, message: message, errorCode: errorCode)) {
      return;
    }
    _stopMetricsPolling();
    _clearCallbacks();
    unawaited(
      _releaseAutomationResources(reason: 'automation_failure')
          .whenComplete(_disposeSessionAsync)
          .whenComplete(_shutdownRuntimeAfterDisposal),
    );
    _finish();
  }

  bool _markFailure({
    required String failureStage,
    required String message,
    int? errorCode,
  }) {
    if (_terminal) {
      return false;
    }
    _terminal = true;
    _markerSink.failure(
      failureStage: failureStage,
      message: message,
      errorCode: errorCode,
    );
    return true;
  }

  void _finish() {
    if (!mounted) {
      return;
    }
    setState(() {
      _finished = true;
    });
  }

  void _clearCallbacks() {
    _commandProbe = null;
    _session?.clearCallbacks();
  }

  Future<void> _releaseAutomationResources({required String reason}) async {
    final DemoDeviceServerController? deviceServerController = _deviceServerController;
    if (deviceServerController != null) {
      await deviceServerController.release(reason: reason);
      await deviceServerController.shutdownRuntime();
      return;
    }
    if (_service != null) {
      await _releaseServerRoleResources(reason: reason);
    } else {
      await _session?.release(reason: reason);
    }
    _audioSession.releaseIfNeeded(reason: reason);
  }

  Future<int> _runAutomationTeardown() async {
    _clearCallbacks();
    await _releaseAutomationResources(reason: 'automation_teardown');
    await _disposeSessionAsync();
    final int shutdownCode = await _shutdownRuntimeAfterDisposal();
    if (shutdownCode != 0) {
      return shutdownCode;
    }
    _finish();
    _markerSink.passed('teardown_completed', payload: <String, Object?>{
      'returned_to_configure': true,
    });
    return 0;
  }

  Future<int> _releaseServerRoleResources({required String reason}) async {
    TiRtcLogging.i('flutter_example', 'server_release_requested reason=$reason');
    await _session?.detachAndStopLocalInputs();
    _session?.releaseBoundConnection();

    final TiRtcConnService? service = _service;
    if (service == null) {
      return 0;
    }
    final int stopCode = service.stop();
    service.dispose();
    if (identical(_service, service)) {
      _service = null;
    }
    return stopCode;
  }

  Future<void> _disposeSessionAsync() async {
    _stopMetricsPolling();
    final DemoDownlinkSession? session = _session;
    _session = null;
    _metricsOverlay = null;
    _lastAvStatsOverlay = null;
    _videoRenderingVisible = false;
    await session?.disposeAsync();
  }

  Future<int> _shutdownRuntimeAfterDisposal() async {
    int code = TiRtc.shutdown();
    for (int attempt = 0; attempt < 10 && code == _runtimeObjectsLiveCode; attempt += 1) {
      await Future<void>.delayed(_stagePollInterval);
      code = TiRtc.shutdown();
    }
    return code;
  }

  void _syncDeviceServerControllerState() {
    final DemoDeviceServerController? controller = _deviceServerController;
    if (controller == null || !mounted) {
      return;
    }
    setState(() {
      _session = controller.session;
      _videoRenderingVisible = controller.localPreviewVisible;
    });
  }

  void _setVideoRendering() {
    if (!mounted) {
      return;
    }
    setState(() {
      _videoRenderingVisible = true;
    });
  }

  void _updateMetricsOverlay(DownlinkMetricsOverlayModel metrics) {
    if (metrics.avStatsReady) {
      _lastAvStatsOverlay = metrics;
    }
    if (!mounted) {
      _metricsOverlay = metrics;
      return;
    }
    setState(() {
      _metricsOverlay = metrics;
    });
  }

  void _startMetricsPolling({required int requestedDecoderPreference}) {
    _stopMetricsPolling();
    _metricsPollTimer = Timer.periodic(_metricsPollInterval, (_) {
      _pollMetricsOverlay(requestedDecoderPreference: requestedDecoderPreference);
    });
  }

  void _pollMetricsOverlay({required int requestedDecoderPreference}) {
    final DemoDownlinkSession? session = _session;
    if (!mounted || session == null) {
      return;
    }
    final DownlinkMetricsOverlayModel? metrics = session.readMetricsOverlay(
      requestedDecoderPreference: requestedDecoderPreference,
    );
    if (metrics != null) {
      _updateMetricsOverlay(metrics);
    }
  }

  void _stopMetricsPolling() {
    _metricsPollTimer?.cancel();
    _metricsPollTimer = null;
  }

  Future<void> _showMetricsExplanationDialog() {
    return context.showNoticeDialog(
      title: '指标说明',
      content: downlinkMetricsExplanationContent,
      contentMaxWidth: 520,
      contentMaxHeightFactor: 0.68,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return const DemoConfigurePage();
    }
    return Scaffold(
      backgroundColor: ExampleTheme.background,
      appBar: AppBar(
        title: Text(
          widget.parseResult.payload?.remoteId ?? 'automation',
          style: const TextStyle(
            color: ExampleTheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DownlinkVideoStage(
              videoView:
                  widget.parseResult.payload?.scenario == AutomationPayload.scenarioFlutterDeviceServerToCliClient
                      ? _session?.buildLocalPreview() ?? const SizedBox.expand()
                      : _session?.buildVideoView() ?? const SizedBox.expand(),
              showStageOverlay: !_videoRenderingVisible,
              stageStatusLabel: '加载中',
              indicatorMode: DownlinkCenterIndicatorMode.loading,
            ),
          ),
          const Positioned.fill(child: DownlinkOverlayGradient()),
          if (_metricsOverlay != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 18, left: 18),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: DownlinkMetricsOverlay(
                    metrics: _metricsOverlay!,
                    onShowExplanation: _showMetricsExplanationDialog,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
