import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';
import '../demo_downlink_session.dart';
import '../demo_downlink_support.dart';
import '../demo_route_lifecycle.dart';
import '../demo_test_hooks.dart';
import '../demo_video_attach_flow.dart';
import '../demo_widget_keys.dart';
import '../widgets/command_panel.dart';
import '../widgets/command_panel_model.dart';
import '../widgets/notice_dialog.dart';
import '../widgets/downlink_center_loading.dart';
import '../widgets/downlink_metrics_overlay.dart';
import '../widgets/player_page_widgets.dart';

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
  final DemoLogUploader _logUploader = DemoLogUploader();
  late final DemoDownlinkSession _session;

  _DownlinkViewState _downlinkState = _DownlinkViewState.idle;
  String _stageStatusLabel = '加载中';
  bool _shouldKeepPlaying = true;
  int _sessionGeneration = 0;
  bool _uploadingLogs = false;
  bool _commandConnected = false;
  bool _smokeConnectedMarked = false;
  bool _smokeAudioPlayingMarked = false;
  bool _smokeVideoRenderingMarked = false;
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

  @override
  void initState() {
    super.initState();
    _session = DemoDownlinkSession();
  }

  @override
  void dispose() {
    _sessionGeneration += 1;
    _stopMetricsPolling();
    _metricsOverlay = null;
    _lastAvStatsOverlay = null;
    _commandConnected = false;
    _commandEvents = <DemoCommandPanelEvent>[];
    _commandSheetSetState = null;
    _clearSessionCallbacks();
    _disconnectSession(reason: 'dispose');
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
      applyOptions: () => _session.setVideoOptions(decoderPreference: requestedDecoderPreference),
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
      _disconnectSession(reason: 'stale_start');
      return;
    }

    if (mounted) {
      setState(() {
        _stageStatusLabel = '连接中';
      });
    }
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
    _stopMetricsPolling();
    _clearMetricsOverlay();
    _clearCommandState();
    _clearSessionCallbacks();
    _disconnectSession(reason: reason);
    _shouldKeepPlaying = !clearIntent;

    if (!mounted) {
      return;
    }
    setState(() {
      _downlinkState = _DownlinkViewState.idle;
      _stageStatusLabel = clearIntent ? '已停止' : '加载中';
    });
  }

  void _disconnectSession({required String reason}) {
    _session.disconnect(reason: reason);
    _audioSession.releaseIfNeeded(reason: reason);
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
        payload: nextMetrics.debugMarkerPayload(sessionGeneration: generation),
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
        return;
      }
      setState(() {
        _commandConnected = true;
        _downlinkState = _DownlinkViewState.connecting;
        _stageStatusLabel = '加载中';
      });
      return;
    }

    if (state == TiRtcConnState.disconnected) {
      setState(() {
        _commandConnected = false;
      });
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

    if (state == TiRtcVideoOutputState.rendering && _downlinkState == _DownlinkViewState.connecting) {
      setState(() {
        _downlinkState = _DownlinkViewState.playing;
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
    _disconnectSession(reason: 'failure');
    setState(() {
      _downlinkState = _DownlinkViewState.failed;
      _stageStatusLabel = label;
      _metricsOverlay = null;
      _commandConnected = false;
    });
    TiRtcLogging.w('flutter_example', 'downlink_failed summary=$summary');
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
      final Map<String, Object?> markerPayload = markerStats.debugMarkerPayload(sessionGeneration: generation);
      _smokeRenderWindowMarked = true;
      widget.smokeMarkerSink?.passed('smoke_render_window_completed', payload: <String, Object?>{
        'audio_error_count': _smokeAudioErrorCount,
        'video_error_count': _smokeVideoErrorCount,
        'audio_state': _session.audioState.name,
        'video_state': _session.videoState.name,
        'audio_input_bitrate_kbps': markerPayload['audio_input_bitrate_kbps'],
        'video_input_bitrate_kbps': markerPayload['video_input_bitrate_kbps'],
        'video_render_fps': markerPayload['video_render_fps'],
        'video_rate_window_duration_ms': markerPayload['video_rate_window_duration_ms'],
        'runtime_focus_log': markerPayload['runtime_focus_log'],
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
  }

  Future<int> _sendCommand(int commandId, Uint8List payload) async {
    final int code = _session.sendCommand(commandId: commandId, payload: payload);
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            _commandSheetSetState = setSheetState;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: Container(
                height: MediaQuery.sizeOf(context).height / 2,
                decoration: const BoxDecoration(
                  color: ExampleTheme.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              '发送命令',
                              style: TextStyle(
                                color: ExampleTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: ExampleTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: ExampleTheme.inputBorder),
                    Expanded(
                      child: DemoCommandPanel(
                        connected: _commandConnected,
                        events: _commandEvents,
                        onSendCommand: (int commandId, Uint8List payload) async {
                          final int code = await _sendCommand(commandId, payload);
                          if (sheetContext.mounted) {
                            setSheetState(() {});
                          }
                          return code;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        _commandSheetSetState = null;
      }
    });
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
              showStageOverlay: _downlinkState != _DownlinkViewState.playing,
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
                  Align(
                    alignment: Alignment.bottomRight,
                    child: DownlinkControlButton(
                      connecting: connecting,
                      playing: playing,
                      onPressed: _toggleDownlink,
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
}
