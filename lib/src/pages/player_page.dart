import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';
import '../demo_downlink_session.dart';
import '../demo_downlink_support.dart';
import '../demo_echo_command.dart';
import '../demo_permissions.dart';
import '../demo_route_lifecycle.dart';
import '../demo_stream_message.dart';
import '../demo_test_hooks.dart';
import '../demo_video_attach_flow.dart';
import '../demo_widget_keys.dart';
import '../widgets/command_panel_model.dart';
import '../widgets/command_panel_sheet.dart';
import '../widgets/notice_dialog.dart';
import '../widgets/downlink_center_loading.dart';
import '../widgets/downlink_metrics_overlay.dart';
import '../widgets/downlink_metrics_overlay_markers.dart';
import '../widgets/downlink_metrics_overlay_model.dart';
import '../widgets/player_page_widgets.dart';
import '../widgets/stream_message_bubble.dart';

enum _DownlinkViewState { idle, connecting, playing, failed }

class DemoPlayerPage extends StatefulWidget {
  const DemoPlayerPage({
    super.key,
    required this.configuration,
    this.smokeMarkerSink,
    this.smokeRenderWindowSeconds = 30,
  });

  final DemoDownlinkConfiguration configuration;
  final DemoAutomationMarkerSink? smokeMarkerSink;
  final int smokeRenderWindowSeconds;

  @override
  State<DemoPlayerPage> createState() => _DemoPlayerPageState();
}

class _DemoPlayerPageState extends State<DemoPlayerPage>
    with WidgetsBindingObserver, ExampleRouteLifecycleState<DemoPlayerPage> {
  static const Duration _metricsPollInterval = Duration(seconds: 1);

  final DemoDownlinkAudioSession _audioSession = DemoDownlinkAudioSession();
  final DemoExamplePermissions _permissions = const DemoExamplePermissions();
  final DemoLogUploader _logUploader = DemoLogUploader();
  final DemoEchoCommandResponder _echoResponder = DemoEchoCommandResponder();
  late final DemoDownlinkSession _session;

  _DownlinkViewState _downlinkState = _DownlinkViewState.idle;
  String _stageStatusLabel = '加载中';
  bool _shouldKeepPlaying = true;
  int _sessionGeneration = 0;
  bool _uploadingLogs = false;
  bool _commandConnected = false;
  bool _localAudioRunning = false;
  bool _localAudioBusy = false;
  int? _localAudioAttachedStreamId;
  int _localAudioStartCount = 0;
  int _localAudioStopCount = 0;
  bool _smokeConnectedMarked = false;
  bool _smokeAudioPlayingMarked = false;
  bool _smokeVideoRenderingMarked = false;
  bool _hasRenderedVideoOnce = false;
  bool _smokeDebugStatsMarked = false;
  bool _smokeRenderWindowStarted = false;
  bool _smokeRenderWindowMarked = false;
  int _smokeAudioErrorCount = 0;
  int _smokeVideoErrorCount = 0;
  Timer? _metricsPollTimer;
  DownlinkMetricsOverlayModel? _metricsOverlay;
  DownlinkMetricsOverlayModel? _lastAvStatsOverlay;
  List<DemoCommandPanelEvent> _commandEvents = <DemoCommandPanelEvent>[];
  StateSetter? _commandSheetSetState;
  final DemoStreamMessageOverlayController _streamMessageOverlay = DemoStreamMessageOverlayController();

  @override
  void initState() {
    super.initState();
    _session = DemoDownlinkSession();
  }

  @override
  void dispose() {
    _sessionGeneration += 1;
    _stopMetricsPolling();
    _streamMessageOverlay.dispose();
    _metricsOverlay = null;
    _lastAvStatsOverlay = null;
    _commandConnected = false;
    _localAudioRunning = false;
    _localAudioBusy = false;
    _localAudioAttachedStreamId = null;
    _commandEvents = <DemoCommandPanelEvent>[];
    _commandSheetSetState = null;
    _clearSessionCallbacks();
    _session.dispose();
    super.dispose();
  }

  @override
  void onRouteActive(String reason) {
    if (_shouldKeepPlaying) {
      unawaited(_startDownlink(reason: reason));
    }
  }

  @override
  void onRouteInactive(String reason) {
    unawaited(
      _stopDownlink(
        reason: reason,
        clearIntent: false,
        nextStatusSummary: 'Downlink paused while the page is inactive.',
      ),
    );
  }

  Future<void> _startDownlink({required String reason}) async {
    if (_downlinkState == _DownlinkViewState.connecting || _downlinkState == _DownlinkViewState.playing) {
      return;
    }

    _shouldKeepPlaying = true;
    final int generation = ++_sessionGeneration;

    setState(() {
      _downlinkState = _DownlinkViewState.connecting;
      _stageStatusLabel = '连接中';
      _hasRenderedVideoOnce = false;
    });

    TiRtcLogging.i(
      'flutter_example',
      'downlink_start_requested reason=$reason '
          'remoteId=${widget.configuration.remoteId}',
    );

    final int audioSessionCode = await _audioSession.retainIfNeeded();
    if (!_acceptGeneration(generation)) {
      _audioSession.releaseIfNeeded(reason: 'stale_audio_session_retain');
      return;
    }
    if (audioSessionCode != 0) {
      _handleFailure(
        generation: generation,
        label: '播放准备失败 · ${TiRtc.formatError(audioSessionCode)}',
        summary: 'Downlink audio session setup failed with ${TiRtc.formatError(audioSessionCode)}.',
      );
      return;
    }

    _bindSessionCallbacks(generation: generation);

    final int connectCode = _session.connect(
      remoteId: widget.configuration.remoteId,
      token: widget.configuration.token,
    );
    if (connectCode != 0) {
      _clearSessionCallbacks();
      _handleFailure(
        generation: generation,
        label: _connectionErrorLabel(connectCode),
        summary: 'Connection setup failed with ${TiRtc.formatError(connectCode)}.',
      );
      return;
    }

    final TiRtcOutputBufferStrategy outputBufferStrategy = _outputBufferStrategy(widget.configuration.settings);
    final int audioOptionsCode = _session.setAudioOptions(bufferStrategy: outputBufferStrategy);
    if (audioOptionsCode != 0) {
      _clearSessionCallbacks();
      _session.disconnectConnection();
      _handleFailure(
        generation: generation,
        label: _downlinkErrorLabel(audioOptionsCode),
        summary: 'Audio output buffer options failed with ${TiRtc.formatError(audioOptionsCode)}.',
      );
      return;
    }

    final int audioAttachCode = _session.attachAudio(streamId: widget.configuration.audioStreamId);
    if (audioAttachCode != 0) {
      _clearSessionCallbacks();
      _session.disconnectConnection();
      _handleFailure(
        generation: generation,
        label: _downlinkErrorLabel(audioAttachCode),
        summary: 'Audio attach failed with ${TiRtc.formatError(audioAttachCode)}.',
      );
      return;
    }

    final int videoStreamId = widget.configuration.videoStreamId;
    final int requestedDecoderPreference = widget.configuration.settings.videoDecoderPreference;
    final DemoVideoAttachResult videoAttachResult = applyVideoDecoderPreferenceThenAttach(
      sessionGeneration: generation,
      videoStreamId: videoStreamId,
      requestedPreference: requestedDecoderPreference,
      applyOptions: () => _session.setVideoOptions(
        decoderPreference: requestedDecoderPreference,
        bufferStrategy: outputBufferStrategy,
      ),
      attachVideo: () => _session.attachVideo(streamId: videoStreamId),
      log: (String message) => TiRtcLogging.i('flutter_example', message),
    );
    if (!videoAttachResult.optionsApplied) {
      _clearSessionCallbacks();
      _session.detachAudio();
      _session.disconnectConnection();
      _handleFailure(
        generation: generation,
        label: _downlinkErrorLabel(videoAttachResult.optionsCode),
        summary: 'Video decoder preference apply failed with ${TiRtc.formatError(videoAttachResult.optionsCode)}.',
      );
      return;
    }

    final int videoAttachCode = videoAttachResult.attachCode ?? 0;
    if (videoAttachCode != 0) {
      _clearSessionCallbacks();
      _session.detachAudio();
      _session.disconnectConnection();
      _handleFailure(
        generation: generation,
        label: _downlinkErrorLabel(videoAttachCode),
        summary: 'Video attach failed with ${TiRtc.formatError(videoAttachCode)}.',
      );
      return;
    }

    if (!_acceptGeneration(generation)) {
      _clearSessionCallbacks();
      await _releaseSession(reason: 'stale_start');
      return;
    }

    if (mounted) {
      setState(() {
        _stageStatusLabel = '连接中';
      });
    }
  }

  TiRtcOutputBufferStrategy _outputBufferStrategy(DemoExampleSettings settings) {
    return settings.outputBufferPolicy == DemoExampleSettings.outputBufferPolicyNoBuffer
        ? TiRtcOutputBufferStrategy.noBuffer
        : TiRtcOutputBufferStrategy.automatic;
  }

  void _bindSessionCallbacks({required int generation}) {
    _session.bindCallbacks(
      onConnectionStateChanged: (TiRtcConnState state, int errorCode) {
        _handleConnectionState(
          generation: generation,
          state: state,
          errorCode: errorCode,
        );
      },
      onAudioStateChanged: (TiRtcAudioOutputState state) {
        _handleAudioState(generation: generation, state: state);
      },
      onAudioError: (int code) {
        _smokeAudioErrorCount += 1;
        _smokeFail(failureStage: 'audio_output', message: 'audio output failed', errorCode: code);
        _handleFailure(
          generation: generation,
          label: _downlinkErrorLabel(code),
          summary: 'Audio output failed with ${TiRtc.formatError(code)}.',
        );
      },
      onVideoStateChanged: (TiRtcVideoOutputState state) {
        _handleVideoState(generation: generation, state: state);
      },
      onVideoError: (int code) {
        _smokeVideoErrorCount += 1;
        _smokeFail(failureStage: 'video_output', message: 'video output failed', errorCode: code);
        _handleFailure(
          generation: generation,
          label: _downlinkErrorLabel(code),
          summary: 'Video output failed with ${TiRtc.formatError(code)}.',
        );
      },
      onCommand: (int commandId, Uint8List data) {
        _handleCommand(
          generation: generation,
          commandId: commandId,
          payload: data,
        );
      },
      onStreamMessage: (int streamId, int timestampMs, Uint8List data) {
        _handleStreamMessage(
          generation: generation,
          streamId: streamId,
          timestampMs: timestampMs,
          payload: data,
        );
      },
      onAudioInputStateChanged: (TiRtcInputState state) {
        _handleLocalAudioInputState(generation: generation, state: state);
      },
      onAudioInputError: (int code, String? message) {
        _handleLocalAudioInputError(generation: generation, code: code, message: message);
      },
    );
  }

  void _clearSessionCallbacks() {
    _session.clearCallbacks();
  }

  Future<void> _stopDownlink({
    required String reason,
    required bool clearIntent,
    required String nextStatusSummary,
  }) async {
    _sessionGeneration += 1;
    if (!_smokeRenderWindowMarked) {
      _smokeRenderWindowStarted = false;
    }
    _stopMetricsPolling();
    _streamMessageOverlay.clear();
    _clearMetricsOverlay();
    _clearCommandState();
    _clearSessionCallbacks();
    await _releaseSession(reason: reason);
    _shouldKeepPlaying = !clearIntent;

    if (!mounted) {
      return;
    }
    setState(() {
      _downlinkState = _DownlinkViewState.idle;
      _stageStatusLabel = clearIntent ? '已停止' : '加载中';
      _hasRenderedVideoOnce = false;
    });
  }

  Future<void> _releaseSession({required String reason}) async {
    await _session.release(reason: reason);
    _audioSession.releaseIfNeeded(reason: reason);
    _localAudioAttachedStreamId = null;
    if (!mounted) {
      _localAudioRunning = false;
      _localAudioBusy = false;
      return;
    }
    setState(() {
      _localAudioRunning = false;
      _localAudioBusy = false;
    });
  }

  void _clearMetricsOverlay() {
    if (!mounted) {
      _metricsOverlay = null;
      _lastAvStatsOverlay = null;
      return;
    }
    setState(() {
      _metricsOverlay = null;
      _lastAvStatsOverlay = null;
      _streamMessageOverlay.clear();
    });
  }

  void _clearCommandState() {
    if (!mounted) {
      _commandConnected = false;
      _commandEvents = <DemoCommandPanelEvent>[];
      _commandSheetSetState = null;
      return;
    }
    setState(() {
      _commandConnected = false;
      _commandEvents = <DemoCommandPanelEvent>[];
    });
    _refreshCommandSheet();
  }

  void _handleStreamMessage({
    required int generation,
    required int streamId,
    required int timestampMs,
    required Uint8List payload,
  }) {
    if (!_acceptGeneration(generation) || streamId != widget.configuration.videoStreamId) {
      return;
    }
    final DemoStreamMessageReceiveEvent? event = _streamMessageOverlay.handleIncoming(
      expectedStreamId: widget.configuration.videoStreamId,
      streamId: streamId,
      timestampMs: timestampMs,
      payload: payload,
      isActive: () => _acceptGeneration(generation),
      onChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    if (event == null) {
      return;
    }
    TiRtcLogging.i(
      'flutter_example',
      'stream_message_received stream_id=${event.streamId} timestamp_ms=${event.timestampMs} '
          'payload_epoch_seconds=${event.epochSeconds} count=${event.count}',
    );
    widget.smokeMarkerSink?.passed('stream_message_received', payload: <String, Object?>{
      'stream_id': event.streamId,
      'payload_epoch_seconds': event.epochSeconds,
      'payload_bytes': event.payloadBytes,
      'payload_hash': event.payloadHash,
      'received_count': event.count,
    });
  }

  void _startMetricsPolling({required int generation}) {
    _stopMetricsPolling();
    _pollDownlinkMetrics(generation: generation);
    _metricsPollTimer = Timer.periodic(_metricsPollInterval, (_) {
      _pollDownlinkMetrics(generation: generation);
    });
  }

  void _stopMetricsPolling() {
    _metricsPollTimer?.cancel();
    _metricsPollTimer = null;
  }

  void _pollDownlinkMetrics({required int generation}) {
    if (!_acceptGeneration(generation) || _downlinkState != _DownlinkViewState.playing) {
      return;
    }

    final DownlinkMetricsOverlayModel? nextMetrics = _session.readMetricsOverlay(
      requestedDecoderPreference: widget.configuration.settings.videoDecoderPreference,
    );
    if (nextMetrics == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _metricsOverlay = nextMetrics;
    });
    if (nextMetrics.avStatsReady) {
      _lastAvStatsOverlay = nextMetrics;
    }
    if (nextMetrics.debugStatsReady) {
      _smokePassOnce(
        marker: 'smoke_debug_stats_ready',
        marked: _smokeDebugStatsMarked,
        setMarked: () {
          _smokeDebugStatsMarked = true;
        },
        payload: nextMetrics.smokeDebugMarkerPayload(sessionGeneration: generation),
      );
      _startSmokeRenderWindow(generation: generation);
    }
  }

  bool _acceptGeneration(int generation) {
    return mounted && generation == _sessionGeneration;
  }

  String _downlinkErrorLabel(int code) {
    return '播放失败 · ${TiRtc.formatError(code)}';
  }

  String _connectionErrorLabel(int code) {
    return '连接失败 · ${TiRtc.formatError(code)}';
  }

  void _handleConnectionState({
    required int generation,
    required TiRtcConnState state,
    required int errorCode,
  }) {
    if (!_acceptGeneration(generation)) {
      return;
    }

    TiRtcLogging.i(
      'flutter_example',
      'connection_state generation=$generation state=$state errorCode=$errorCode',
    );

    if (state == TiRtcConnState.connecting) {
      if (_downlinkState == _DownlinkViewState.playing) {
        return;
      }
      setState(() {
        _downlinkState = _DownlinkViewState.connecting;
        _stageStatusLabel = '连接中';
      });
      return;
    }

    if (state == TiRtcConnState.connected) {
      _smokePassOnce(
        marker: 'smoke_connected',
        marked: _smokeConnectedMarked,
        setMarked: () {
          _smokeConnectedMarked = true;
        },
        payload: <String, Object?>{'remote_id': widget.configuration.remoteId},
      );
      if (_downlinkState == _DownlinkViewState.playing) {
        _setCommandConnected(true);
        return;
      }
      setState(() {
        _commandConnected = true;
        _downlinkState = _DownlinkViewState.connecting;
        _stageStatusLabel = '加载中';
      });
      _refreshCommandSheet();
      return;
    }

    if (state == TiRtcConnState.disconnected) {
      _setCommandConnected(false);
      if (errorCode == 0) {
        _handleFailure(
          generation: generation,
          label: '连接断开 #0',
          summary: 'Remote session disconnected.',
        );
      } else {
        _handleFailure(
          generation: generation,
          label: _connectionErrorLabel(errorCode),
          summary: 'Connection disconnected with ${TiRtc.formatError(errorCode)}.',
        );
      }
    }
  }

  void _handleAudioState({
    required int generation,
    required TiRtcAudioOutputState state,
  }) {
    if (!_acceptGeneration(generation)) {
      return;
    }

    if (state == TiRtcAudioOutputState.failed) {
      _smokeAudioErrorCount += 1;
      _smokeFail(failureStage: 'audio_output', message: 'audio output entered failed state');
      _handleFailure(
        generation: generation,
        label: _downlinkErrorLabel(0),
        summary: 'Audio output entered a failed state.',
      );
      return;
    }

    if (state == TiRtcAudioOutputState.playing) {
      _smokePassOnce(
        marker: 'smoke_audio_playing',
        marked: _smokeAudioPlayingMarked,
        setMarked: () {
          _smokeAudioPlayingMarked = true;
        },
        payload: <String, Object?>{'audio_error_count': _smokeAudioErrorCount},
      );
    }
  }

  void _handleLocalAudioInputState({
    required int generation,
    required TiRtcInputState state,
  }) {
    if (!_acceptGeneration(generation)) {
      return;
    }
    TiRtcLogging.i('flutter_example', 'local_audio_input_state state=${state.name}');
    if (state == TiRtcInputState.running && !_localAudioRunning) {
      setState(() {
        _localAudioRunning = true;
      });
    } else if (state != TiRtcInputState.running && _localAudioRunning) {
      setState(() {
        _localAudioRunning = false;
      });
    }
  }

  void _handleLocalAudioInputError({
    required int generation,
    required int code,
    String? message,
  }) {
    if (!_acceptGeneration(generation)) {
      return;
    }
    TiRtcLogging.w('flutter_example', 'local_audio_input_error code=$code message=${message ?? ''}');
    widget.smokeMarkerSink?.failure(
      failureStage: 'local_audio_input',
      message: 'local audio input failed',
      errorCode: code,
    );
    if (mounted) {
      setState(() {
        _localAudioRunning = false;
        _localAudioBusy = false;
      });
    }
  }

  void _handleVideoState({
    required int generation,
    required TiRtcVideoOutputState state,
  }) {
    if (!_acceptGeneration(generation)) {
      return;
    }

    if (state == TiRtcVideoOutputState.failed) {
      _smokeVideoErrorCount += 1;
      _smokeFail(failureStage: 'video_output', message: 'video output entered failed state');
      _handleFailure(
        generation: generation,
        label: _downlinkErrorLabel(0),
        summary: 'Video output entered a failed state.',
      );
      return;
    }

    if (state == TiRtcVideoOutputState.rendering) {
      setState(() {
        if (_downlinkState == _DownlinkViewState.connecting) {
          _downlinkState = _DownlinkViewState.playing;
        }
        _hasRenderedVideoOnce = true;
      });
      _markSmokeVideoRendering(generation: generation);
      _startMetricsPolling(generation: generation);
    }
  }

  void _handleFailure({
    required int generation,
    required String label,
    required String summary,
  }) {
    if (!_acceptGeneration(generation)) {
      return;
    }

    _sessionGeneration += 1;
    _stopMetricsPolling();
    _clearSessionCallbacks();
    unawaited(_releaseSession(reason: 'failure'));
    setState(() {
      _downlinkState = _DownlinkViewState.failed;
      _stageStatusLabel = label;
      _metricsOverlay = null;
      _commandConnected = false;
    });
    TiRtcLogging.w('flutter_example', 'downlink_failed summary=$summary');
    _refreshCommandSheet();
    _smokeFail(failureStage: 'downlink', message: summary);
  }

  void _smokePassOnce({
    required String marker,
    required bool marked,
    required VoidCallback setMarked,
    required Map<String, Object?> payload,
  }) {
    if (marked) {
      return;
    }
    setMarked();
    widget.smokeMarkerSink?.passed(marker, payload: payload);
  }

  void _smokeFail({
    required String failureStage,
    required String message,
    int? errorCode,
  }) {
    widget.smokeMarkerSink?.failure(
      failureStage: failureStage,
      message: message,
      errorCode: errorCode,
    );
  }

  void _markSmokeVideoRendering({required int generation}) {
    if (_smokeVideoRenderingMarked || widget.smokeMarkerSink == null) {
      return;
    }
    _smokeVideoRenderingMarked = true;
    unawaited(() async {
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        if (!_acceptGeneration(generation)) {
          return;
        }
        final TiRtcVideoOutputMetricsResult metrics = _session.videoMetrics();
        final int? firstFrameDurationMs = metrics.snapshot?.startup.firstFrameDurationMs;
        if (metrics.code == 0 && firstFrameDurationMs != null && firstFrameDurationMs >= 0) {
          widget.smokeMarkerSink?.passed('smoke_video_rendering', payload: <String, Object?>{
            'first_frame_duration_ms': firstFrameDurationMs,
          });
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      _smokeFail(failureStage: 'render_timeout', message: 'first frame metrics timeout');
    }());
  }

  void _startSmokeRenderWindow({required int generation}) {
    if (_smokeRenderWindowStarted || widget.smokeMarkerSink == null) {
      return;
    }
    _smokeRenderWindowStarted = true;
    unawaited(() async {
      await Future<void>.delayed(Duration(seconds: widget.smokeRenderWindowSeconds));
      if (!_acceptGeneration(generation) || _smokeRenderWindowMarked) {
        return;
      }
      final DownlinkMetricsOverlayModel? metrics = _session.readMetricsOverlay(
        requestedDecoderPreference: widget.configuration.settings.videoDecoderPreference,
      );
      if (_smokeAudioErrorCount != 0 ||
          _smokeVideoErrorCount != 0 ||
          _session.videoState != TiRtcVideoOutputState.rendering ||
          metrics == null ||
          !metrics.debugStatsReady) {
        _smokeFail(failureStage: 'render_window', message: 'render window ended without healthy output');
        return;
      }
      final DownlinkMetricsOverlayModel markerStats = _lastAvStatsOverlay ?? metrics;
      final Map<String, Object?> markerPayload = markerStats.smokeRenderWindowMarkerPayload(
        sessionGeneration: generation,
      );
      _smokeRenderWindowMarked = true;
      widget.smokeMarkerSink?.passed('smoke_render_window_completed', payload: <String, Object?>{
        ...markerPayload,
        'audio_error_count': _smokeAudioErrorCount,
        'video_error_count': _smokeVideoErrorCount,
        'audio_state': _session.audioState.name,
        'video_state': _session.videoState.name,
      });
    }());
  }

  void _handleCommand({
    required int generation,
    required int commandId,
    required Uint8List payload,
  }) {
    if (!_acceptGeneration(generation)) {
      return;
    }
    _appendCommandEvent(
      DemoCommandPanelEvent(
        direction: DemoCommandEventDirection.received,
        commandId: commandId,
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
    final int? echoCode = _echoResponder.handleReceived(
      commandId: commandId,
      payload: payload,
      sendCommand: (int commandId, Uint8List payload) => _session.sendCommand(commandId: commandId, payload: payload),
    );
    if (echoCode != null) {
      _appendCommandEvent(
        DemoCommandPanelEvent(
          direction: DemoCommandEventDirection.sent,
          commandId: commandId,
          payload: payload,
          resultCode: echoCode,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  void _setCommandConnected(bool connected) {
    if (_commandConnected == connected) {
      return;
    }
    if (!mounted) {
      _commandConnected = connected;
      return;
    }
    setState(() {
      _commandConnected = connected;
    });
    _refreshCommandSheet();
  }

  Future<int> _sendCommand(int commandId, Uint8List payload) async {
    final int code = _session.sendCommand(commandId: commandId, payload: payload);
    _echoResponder.trackLocalSend(
      commandId: commandId,
      payload: payload,
      resultCode: code,
    );
    _appendCommandEvent(
      DemoCommandPanelEvent(
        direction: DemoCommandEventDirection.sent,
        commandId: commandId,
        payload: payload,
        resultCode: code,
        createdAt: DateTime.now(),
      ),
    );
    return code;
  }

  void _appendCommandEvent(DemoCommandPanelEvent event) {
    if (!mounted) {
      _commandEvents = trimDemoCommandEvents(<DemoCommandPanelEvent>[..._commandEvents, event]);
      _commandSheetSetState = null;
      return;
    }
    setState(() {
      _commandEvents = trimDemoCommandEvents(<DemoCommandPanelEvent>[..._commandEvents, event]);
    });
    _refreshCommandSheet();
  }

  void _refreshCommandSheet() {
    _commandSheetSetState?.call(() {});
  }

  Future<void> _uploadLogs() async {
    if (_uploadingLogs) {
      return;
    }

    setState(() {
      _uploadingLogs = true;
    });

    try {
      final ({int code, String? logId})? result = await _logUploader.upload(
        remoteId: widget.configuration.remoteId,
        isActive: () => mounted,
        showResult: _showLogUploadResultIfMounted,
      );
      if (result != null && result.code == 0 && (result.logId?.isNotEmpty ?? false)) {
        widget.smokeMarkerSink?.passed('smoke_log_upload_completed', payload: <String, Object?>{
          'log_id': result.logId,
          'code': result.code,
        });
      } else if (widget.smokeMarkerSink != null) {
        _smokeFail(
          failureStage: 'log_upload',
          message: 'log upload failed',
          errorCode: result?.code,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingLogs = false;
        });
      }
    }
  }

  Future<void> _showLogUploadResultIfMounted({
    required String title,
    required String content,
  }) {
    if (!mounted) {
      return Future<void>.value();
    }
    return _showLogUploadResultDialog(title: title, content: content);
  }

  Future<void> _showLogUploadResultDialog({
    required String title,
    required String content,
  }) {
    return context.showNoticeDialog(
      title: title,
      content: content,
    );
  }

  Future<void> _showMetricsExplanationDialog() {
    return context.showNoticeDialog(
      title: '指标说明',
      content: downlinkMetricsExplanationContent,
      contentMaxWidth: 520,
      contentMaxHeightFactor: 0.68,
      contentFontSize: 15,
    );
  }

  Future<void> _showCommandPanel() {
    return showDemoCommandPanelSheet(
      context: context,
      title: '发送命令',
      connected: () => _commandConnected,
      events: () => _commandEvents,
      onSendCommand: _sendCommand,
      onSheetStateChanged: (StateSetter? setState) {
        if (mounted) {
          _commandSheetSetState = setState;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool connecting = _downlinkState == _DownlinkViewState.connecting;
    final bool playing = _downlinkState == _DownlinkViewState.playing;
    return Scaffold(
      key: DemoWidgetKeys.playerPage,
      backgroundColor: ExampleTheme.background,
      appBar: AppBar(
        title: Text(
          widget.configuration.remoteId,
          style: const TextStyle(
            color: ExampleTheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: <Widget>[
          PlayerCommandButton(
            key: DemoWidgetKeys.playerCommandButton,
            onOpenCommands: _showCommandPanel,
          ),
          PlayerLogUploadButton(
            key: DemoWidgetKeys.playerLogUploadButton,
            uploadingLogs: _uploadingLogs,
            onUploadLogs: _uploadLogs,
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DownlinkVideoStage(
              videoView: _session.buildVideoView(),
              showStageOverlay: _showStageOverlay,
              stageStatusLabel: _stageStatusLabel,
              indicatorMode: _centerIndicatorMode,
            ),
          ),
          const Positioned.fill(child: DownlinkOverlayGradient()),
          if (_metricsOverlay != null)
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: SafeArea(
                bottom: false,
                child: DownlinkMetricsOverlay(
                  metrics: _metricsOverlay!,
                  onShowExplanation: _showMetricsExplanationDialog,
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Spacer(),
                  if (_streamMessageOverlay.text != null)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: StreamMessageBubble(
                        text: _streamMessageOverlay.text!,
                      ),
                    ),
                  if (_streamMessageOverlay.text != null) const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        LocalAudioControlButton(
                          key: DemoWidgetKeys.playerLocalAudioButton,
                          enabled: _commandConnected,
                          busy: _localAudioBusy,
                          running: _localAudioRunning,
                          onPressed: _toggleLocalAudio,
                        ),
                        DownlinkControlButton(
                          connecting: connecting,
                          playing: playing,
                          onPressed: _toggleDownlink,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleDownlink() {
    if (_downlinkState == _DownlinkViewState.playing) {
      unawaited(
        _stopDownlink(
          reason: 'manual_stop',
          clearIntent: true,
          nextStatusSummary: 'Downlink stopped.',
        ),
      );
      return;
    }

    unawaited(_startDownlink(reason: 'manual_start'));
  }

  void _toggleLocalAudio() {
    if (_localAudioRunning) {
      unawaited(_stopLocalAudio(reason: 'manual_stop'));
      return;
    }
    unawaited(_startLocalAudio());
  }

  Future<void> _startLocalAudio() async {
    if (_localAudioBusy || !_commandConnected) {
      return;
    }
    setState(() {
      _localAudioBusy = true;
    });

    final bool microphoneReady =
        await _permissions.checkMicrophonePermission() || await _permissions.requestMicrophonePermission();
    if (!mounted || !_commandConnected) {
      if (mounted) {
        setState(() {
          _localAudioBusy = false;
        });
      }
      return;
    }
    if (!microphoneReady) {
      TiRtcLogging.w('flutter_example', 'local_audio_input_permission_denied');
      widget.smokeMarkerSink?.failure(
        failureStage: 'local_audio_permission',
        message: 'microphone permission denied',
      );
      _showLocalAudioSnack('麦克风权限未授权。');
      if (mounted) {
        setState(() {
          _localAudioBusy = false;
        });
      }
      return;
    }

    final DemoExampleSettings settings = widget.configuration.settings;
    final int streamId = settings.localAudioStreamId;
    final TiRtcAudioInputOptions options = _localAudioOptions(settings);
    TiRtcLogging.i(
      'flutter_example',
      'local_audio_input_start_requested stream_id=$streamId '
          'codec=${settings.localAudioCodec} sample_rate_hz=${settings.localAudioSampleRateHz} '
          'aec=${settings.localAudioAecEnabled} agc=${settings.localAudioAgcLevel} ans=${settings.localAudioAnsLevel}',
    );

    int code = await _session.prepareLocalAudio(audioOptions: options);
    final int? previousStreamId = _localAudioAttachedStreamId;
    if (code == 0 && _localAudioAttachedStreamId != streamId) {
      if (_localAudioAttachedStreamId != null) {
        await _session.stopLocalAudio();
        await _session.detachLocalAudioFromBoundConnection();
        _localAudioAttachedStreamId = null;
      }
      code = await _session.attachLocalAudio(streamId: streamId);
      if (code == 0) {
        widget.smokeMarkerSink?.passed('local_audio_input_attached', payload: <String, Object?>{
          'stream_id': streamId,
          'previous_stream_id': previousStreamId,
        });
        _localAudioAttachedStreamId = streamId;
      }
    }
    final bool reusedBinding = code == 0 && previousStreamId == streamId;
    if (code == 0) {
      code = await _session.startLocalAudio();
    }
    if (code == 0) {
      _localAudioStartCount += 1;
      TiRtcLogging.i(
        'flutter_example',
        'local_audio_input_start_done stream_id=$streamId start_count=$_localAudioStartCount reused_binding=$reusedBinding',
      );
      widget.smokeMarkerSink?.passed('local_audio_input_started', payload: <String, Object?>{
        'stream_id': streamId,
        'start_count': _localAudioStartCount,
        'stop_count': _localAudioStopCount,
        'reused_binding': reusedBinding,
      });
      if (mounted) {
        setState(() {
          _localAudioRunning = true;
          _localAudioBusy = false;
        });
      }
      return;
    }

    TiRtcLogging.w('flutter_example', 'local_audio_input_start_failed code=$code');
    widget.smokeMarkerSink?.failure(
      failureStage: 'local_audio_start',
      message: 'local audio input start failed',
      errorCode: code,
    );
    _showLocalAudioSnack('麦克风启动失败 · ${TiRtc.formatError(code)}');
    if (mounted) {
      setState(() {
        _localAudioRunning = false;
        _localAudioBusy = false;
      });
    }
  }

  Future<void> _stopLocalAudio({required String reason}) async {
    if (_localAudioBusy) {
      return;
    }
    setState(() {
      _localAudioBusy = true;
    });
    TiRtcLogging.i('flutter_example', 'local_audio_input_stop_requested reason=$reason');
    final int code = await _session.stopLocalAudio();
    if (code == 0) {
      _localAudioStopCount += 1;
      TiRtcLogging.i('flutter_example', 'local_audio_input_stop_done stop_count=$_localAudioStopCount');
      widget.smokeMarkerSink?.passed('local_audio_input_stopped', payload: <String, Object?>{
        'stream_id': _localAudioAttachedStreamId,
        'start_count': _localAudioStartCount,
        'stop_count': _localAudioStopCount,
      });
      if (mounted) {
        setState(() {
          _localAudioRunning = false;
          _localAudioBusy = false;
        });
      }
      return;
    }
    TiRtcLogging.w('flutter_example', 'local_audio_input_stop_failed code=$code');
    _showLocalAudioSnack('麦克风停止失败 · ${TiRtc.formatError(code)}');
    if (mounted) {
      setState(() {
        _localAudioBusy = false;
      });
    }
  }

  TiRtcAudioInputOptions _localAudioOptions(DemoExampleSettings settings) {
    return TiRtcAudioInputOptions(
      codec: switch (settings.localAudioCodec) {
        DemoExampleSettings.localAudioCodecAac => TiRtcAudioCodec.aac,
        DemoExampleSettings.localAudioCodecPcm => TiRtcAudioCodec.pcm,
        _ => TiRtcAudioCodec.g711a,
      },
      sampleRate: settings.localAudioSampleRateHz == DemoExampleSettings.localAudioSampleRate8k
          ? TiRtcAudioSampleRate.rate8k
          : TiRtcAudioSampleRate.rate16k,
      channels: TiRtcAudioChannelCount.mono,
      aecMode: settings.localAudioAecEnabled ? TiRtcAudioAecMode.enabled : TiRtcAudioAecMode.disabled,
      agcLevel: _localAudioAgcLevel(settings.localAudioAgcLevel),
      ansLevel: _localAudioAnsLevel(settings.localAudioAnsLevel),
    );
  }

  TiRtcAudioAgcLevel _localAudioAgcLevel(int value) {
    return switch (value) {
      1 => TiRtcAudioAgcLevel.low,
      2 => TiRtcAudioAgcLevel.medium,
      3 => TiRtcAudioAgcLevel.high,
      _ => TiRtcAudioAgcLevel.disabled,
    };
  }

  TiRtcAudioAnsLevel _localAudioAnsLevel(int value) {
    return switch (value) {
      1 => TiRtcAudioAnsLevel.low,
      2 => TiRtcAudioAnsLevel.medium,
      3 => TiRtcAudioAnsLevel.high,
      _ => TiRtcAudioAnsLevel.disabled,
    };
  }

  void _showLocalAudioSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  DownlinkCenterIndicatorMode get _centerIndicatorMode {
    if (_downlinkState == _DownlinkViewState.connecting) {
      return DownlinkCenterIndicatorMode.loading;
    }

    if (_downlinkState == _DownlinkViewState.failed) {
      return DownlinkCenterIndicatorMode.error;
    }

    if (_downlinkState == _DownlinkViewState.idle && !_shouldKeepPlaying) {
      return DownlinkCenterIndicatorMode.error;
    }

    return DownlinkCenterIndicatorMode.loading;
  }

  bool get _showStageOverlay {
    if (_downlinkState == _DownlinkViewState.playing) {
      return false;
    }
    if (_downlinkState == _DownlinkViewState.failed) {
      return true;
    }
    if (_downlinkState == _DownlinkViewState.idle && !_shouldKeepPlaying) {
      return true;
    }
    return !_hasRenderedVideoOnce;
  }
}
