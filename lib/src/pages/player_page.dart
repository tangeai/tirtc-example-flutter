import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';
import '../demo_route_lifecycle.dart';
import '../widgets/notice_dialog.dart';
import '../widgets/playback_center_loading.dart';
import '../widgets/playback_metrics_overlay.dart';

enum _PlaybackViewState { idle, connecting, playing, failed }

class DemoPlayerPage extends StatefulWidget {
  const DemoPlayerPage({
    super.key,
    required this.configuration,
  });

  final DemoPlaybackConfiguration configuration;

  @override
  State<DemoPlayerPage> createState() => _DemoPlayerPageState();
}

class _DemoPlayerPageState extends State<DemoPlayerPage>
    with WidgetsBindingObserver, ExampleRouteLifecycleState<DemoPlayerPage> {
  static const Duration _metricsPollInterval = Duration(seconds: 1);

  late final TiRtcConn _connection;
  late final TiRtcAudioOutput _audioOutput;
  late final TiRtcVideoOutput _videoOutput;

  _PlaybackViewState _playbackState = _PlaybackViewState.idle;
  String _stageStatusLabel = '加载中';
  bool _shouldKeepPlaying = true;
  int _sessionGeneration = 0;
  bool _uploadingLogs = false;
  bool _iosPlaybackAudioSessionRetained = false;
  Timer? _metricsPollTimer;
  PlaybackMetricsOverlayModel? _metricsOverlay;

  @override
  void initState() {
    super.initState();
    _connection = TiRtcConn();
    _audioOutput = TiRtcAudioOutput();
    _videoOutput = TiRtcVideoOutput();
  }

  @override
  void dispose() {
    _sessionGeneration += 1;
    _stopMetricsPolling();
    _clearSessionCallbacks();
    _disconnectSession(reason: 'dispose');
    _videoOutput.dispose();
    _audioOutput.dispose();
    _connection.dispose();
    super.dispose();
  }

  @override
  void onRouteActive(String reason) {
    if (_shouldKeepPlaying) {
      unawaited(_startPlayback(reason: reason));
    }
  }

  @override
  void onRouteInactive(String reason) {
    unawaited(
      _stopPlayback(
        reason: reason,
        clearIntent: false,
        nextStatusSummary: 'Playback paused while the page is inactive.',
      ),
    );
  }

  Future<void> _startPlayback({required String reason}) async {
    if (_playbackState == _PlaybackViewState.connecting || _playbackState == _PlaybackViewState.playing) {
      return;
    }

    _shouldKeepPlaying = true;
    final int generation = ++_sessionGeneration;

    setState(() {
      _playbackState = _PlaybackViewState.connecting;
      _stageStatusLabel = '连接中';
    });

    TiRtcLogging.i(
      'flutter_example',
      'playback_start_requested reason=$reason '
          'remoteId=${widget.configuration.remoteId}',
    );

    final int audioSessionCode = await _retainPlaybackAudioSessionIfNeeded();
    if (!_acceptGeneration(generation)) {
      _releasePlaybackAudioSessionIfNeeded(reason: 'stale_audio_session_retain');
      return;
    }
    if (audioSessionCode != 0) {
      _handleFailure(
        generation: generation,
        label: '播放准备失败 · ${TiRtc.formatError(audioSessionCode)}',
        summary: 'Playback audio session setup failed with ${TiRtc.formatError(audioSessionCode)}.',
      );
      return;
    }

    _bindSessionCallbacks(generation: generation);

    final int connectCode = _connection.connect(
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

    final int audioAttachCode = _audioOutput.attach(
      connection: _connection,
      streamId: widget.configuration.audioStreamId,
    );
    if (audioAttachCode != 0) {
      _clearSessionCallbacks();
      _connection.disconnect();
      _handleFailure(
        generation: generation,
        label: _playbackErrorLabel(audioAttachCode),
        summary: 'Audio attach failed with ${TiRtc.formatError(audioAttachCode)}.',
      );
      return;
    }

    final int videoAttachCode = _videoOutput.attach(
      connection: _connection,
      streamId: widget.configuration.videoStreamId,
    );
    if (videoAttachCode != 0) {
      _clearSessionCallbacks();
      _audioOutput.detach();
      _connection.disconnect();
      _handleFailure(
        generation: generation,
        label: _playbackErrorLabel(videoAttachCode),
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
    _connection.onStateChanged = (TiRtcConnState state, int errorCode) {
      _handleConnectionState(
        generation: generation,
        state: state,
        errorCode: errorCode,
      );
    };
    _audioOutput.onStateChanged = (TiRtcAudioOutputState state) {
      _handleAudioState(generation: generation, state: state);
    };
    _audioOutput.onError = (int code) {
      _handleFailure(
        generation: generation,
        label: _playbackErrorLabel(code),
        summary: 'Audio output failed with ${TiRtc.formatError(code)}.',
      );
    };
    _videoOutput.onStateChanged = (TiRtcVideoOutputState state) {
      _handleVideoState(generation: generation, state: state);
    };
    _videoOutput.onRenderSizeChanged = null;
    _videoOutput.onError = (int code) {
      _handleFailure(
        generation: generation,
        label: _playbackErrorLabel(code),
        summary: 'Video output failed with ${TiRtc.formatError(code)}.',
      );
    };
  }

  void _clearSessionCallbacks() {
    _connection.onStateChanged = null;
    _audioOutput.onStateChanged = null;
    _audioOutput.onError = null;
    _videoOutput.onStateChanged = null;
    _videoOutput.onRenderSizeChanged = null;
    _videoOutput.onError = null;
  }

  Future<void> _stopPlayback({
    required String reason,
    required bool clearIntent,
    required String nextStatusSummary,
  }) async {
    _sessionGeneration += 1;
    _stopMetricsPolling();
    _clearMetricsOverlay();
    _clearSessionCallbacks();
    _disconnectSession(reason: reason);
    _shouldKeepPlaying = !clearIntent;

    if (!mounted) {
      return;
    }
    setState(() {
      _playbackState = _PlaybackViewState.idle;
      _stageStatusLabel = clearIntent ? '已停止' : '加载中';
    });
  }

  void _disconnectSession({required String reason}) {
    TiRtcLogging.i('flutter_example', 'playback_stop_requested reason=$reason');
    _videoOutput.detach();
    _audioOutput.detach();
    _connection.disconnect();
    _releasePlaybackAudioSessionIfNeeded(reason: reason);
  }

  void _clearMetricsOverlay() {
    if (!mounted) {
      _metricsOverlay = null;
      return;
    }
    setState(() {
      _metricsOverlay = null;
    });
  }

  void _startMetricsPolling({required int generation}) {
    _stopMetricsPolling();
    _pollPlaybackMetrics(generation: generation);
    _metricsPollTimer = Timer.periodic(_metricsPollInterval, (_) {
      _pollPlaybackMetrics(generation: generation);
    });
  }

  void _stopMetricsPolling() {
    _metricsPollTimer?.cancel();
    _metricsPollTimer = null;
  }

  void _pollPlaybackMetrics({required int generation}) {
    if (!_acceptGeneration(generation) || _playbackState != _PlaybackViewState.playing) {
      return;
    }

    final TiRtcConnMetricsResult connResult = _connection.getMetricsSnapshot();
    final TiRtcVideoOutputMetricsResult videoResult = _videoOutput.getMetricsSnapshot();
    if (connResult.code != 0 || videoResult.code != 0) {
      return;
    }

    final TiRtcConnMetricsSnapshot? connSnapshot = connResult.snapshot;
    final TiRtcVideoOutputMetricsSnapshot? videoSnapshot = videoResult.snapshot;
    if (connSnapshot == null || videoSnapshot == null) {
      return;
    }

    final PlaybackMetricsOverlayModel nextMetrics = PlaybackMetricsOverlayModel(
      connectDurationMs: connSnapshot.connectDurationMs,
      firstFrameDurationMs: videoSnapshot.startup.firstFrameDurationMs,
      sessionStutterRatio: videoSnapshot.stutter.sessionStutterRatio,
      sessionStutterCount: videoSnapshot.stutter.sessionStutterCount,
      sessionStutterPeakMs: videoSnapshot.stutter.sessionStutterPeakMs,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _metricsOverlay = nextMetrics;
    });
  }

  Future<int> _retainPlaybackAudioSessionIfNeeded() async {
    if (!Platform.isIOS || _iosPlaybackAudioSessionRetained) {
      return 0;
    }

    TiRtcLogging.i('flutter_example', 'playback_audio_session_retain_requested');
    final int code = await TiRtcHostPlatformApi.instance.retainPlaybackAudioSession();
    if (code == 0) {
      _iosPlaybackAudioSessionRetained = true;
      TiRtcLogging.i('flutter_example', 'playback_audio_session_retain_succeeded');
      return 0;
    }

    TiRtcLogging.w(
      'flutter_example',
      'playback_audio_session_retain_failed code=$code',
    );
    return code;
  }

  void _releasePlaybackAudioSessionIfNeeded({required String reason}) {
    if (!Platform.isIOS || !_iosPlaybackAudioSessionRetained) {
      return;
    }

    _iosPlaybackAudioSessionRetained = false;
    TiRtcLogging.i(
      'flutter_example',
      'playback_audio_session_release_requested reason=$reason',
    );
    unawaited(() async {
      final int code = await TiRtcHostPlatformApi.instance.releasePlaybackAudioSession();
      if (code == 0) {
        TiRtcLogging.i('flutter_example', 'playback_audio_session_release_succeeded reason=$reason');
        return;
      }
      TiRtcLogging.w(
        'flutter_example',
        'playback_audio_session_release_failed reason=$reason code=$code',
      );
    }());
  }

  bool _acceptGeneration(int generation) {
    return mounted && generation == _sessionGeneration;
  }

  String _playbackErrorLabel(int code) {
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
      if (_playbackState == _PlaybackViewState.playing) {
        return;
      }
      setState(() {
        _playbackState = _PlaybackViewState.connecting;
        _stageStatusLabel = '连接中';
      });
      return;
    }

    if (state == TiRtcConnState.connected) {
      if (_playbackState == _PlaybackViewState.playing) {
        return;
      }
      setState(() {
        _playbackState = _PlaybackViewState.connecting;
        _stageStatusLabel = '加载中';
      });
      return;
    }

    if (state == TiRtcConnState.disconnected) {
      _stopMetricsPolling();
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
      _stopMetricsPolling();
      _handleFailure(
        generation: generation,
        label: _playbackErrorLabel(0),
        summary: 'Audio output entered a failed state.',
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
      _stopMetricsPolling();
      _handleFailure(
        generation: generation,
        label: _playbackErrorLabel(0),
        summary: 'Video output entered a failed state.',
      );
      return;
    }

    if (state == TiRtcVideoOutputState.rendering && _playbackState == _PlaybackViewState.connecting) {
      setState(() {
        _playbackState = _PlaybackViewState.playing;
      });
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
      _playbackState = _PlaybackViewState.failed;
      _stageStatusLabel = label;
      _metricsOverlay = null;
    });
    TiRtcLogging.w('flutter_example', 'playback_failed summary=$summary');
  }

  Future<void> _uploadLogs() async {
    if (_uploadingLogs) {
      return;
    }

    setState(() {
      _uploadingLogs = true;
    });
    TiRtcLogging.i(
      'flutter_example',
      'log_upload_requested remoteId=${widget.configuration.remoteId}',
    );

    try {
      final ({int code, String? logId}) result = await TiRtcLogging.upload();
      if (!mounted) {
        return;
      }

      if (result.code == 0) {
        final String message =
            (result.logId?.isNotEmpty ?? false) ? '日志 ID: ${result.logId}\n将此编号提供给开发人员排查' : '日志上传成功。';
        TiRtcLogging.i(
          'flutter_example',
          'log_upload_succeeded logId=${result.logId ?? ''}',
        );
        await _showLogUploadResultDialog(
          title: '日志上传成功',
          content: message,
        );
        return;
      }

      TiRtcLogging.i(
        'flutter_example',
        'log_upload_failed code=${result.code}',
      );
      await _showLogUploadResultDialog(
        title: '日志上传失败',
        content: 'code ${result.code}。',
      );
    } catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        'log_upload_failed unexpected=$error',
      );
      if (mounted) {
        await _showLogUploadResultDialog(
          title: '日志上传失败',
          content: '请重试。',
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
      content: '连接耗时：从发起连接到连接成功的耗时。\n\n'
          '首帧耗时：从发起连接到首帧显示的耗时。\n\n'
          '当前卡顿指标按端上当前判定规则统计，只计入达到阈值的明显卡顿。\n\n'
          '检测到的卡顿占比：从开始播放到现在，按当前端上判定规则识别出的卡顿总时长，占播放总时长的比例。\n\n'
          '检测到的卡顿次数：本次播放中，按当前端上判定规则识别出的连续卡顿事件次数。\n\n'
          '检测到的最长卡顿：本次播放中，按当前端上判定规则识别出的单次最长卡顿时长。',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool connecting = _playbackState == _PlaybackViewState.connecting;
    final bool playing = _playbackState == _PlaybackViewState.playing;
    return Scaffold(
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
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: ExampleTheme.primary,
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(84, 28),
                side: const BorderSide(
                  color: ExampleTheme.primary,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _uploadingLogs ? null : _uploadLogs,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_uploadingLogs) ...<Widget>[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ExampleTheme.primary.withAlpha(214),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _uploadingLogs ? '上传中' : '上传日志',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _buildVideoStage()),
          Positioned.fill(child: _buildOverlayGradient()),
          if (_metricsOverlay != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 18, left: 18),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: PlaybackMetricsOverlay(
                    metrics: _metricsOverlay!,
                    onShowExplanation: _showMetricsExplanationDialog,
                  ),
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
                    child: FilledButton.icon(
                      onPressed: connecting
                          ? null
                          : () {
                              if (playing) {
                                unawaited(
                                  _stopPlayback(
                                    reason: 'manual_stop',
                                    clearIntent: true,
                                    nextStatusSummary: 'Playback stopped.',
                                  ),
                                );
                              } else {
                                unawaited(
                                  _startPlayback(reason: 'manual_start'),
                                );
                              }
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        backgroundColor: playing ? Colors.redAccent.shade200 : ExampleTheme.primary,
                      ),
                      icon: connecting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              playing ? Icons.stop_circle_outlined : Icons.play_circle_fill_rounded,
                            ),
                      label: Text(
                        connecting ? 'Connecting' : (playing ? 'Stop' : 'Connect'),
                      ),
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

  Widget _buildVideoStage() {
    final bool showStageOverlay = _playbackState != _PlaybackViewState.playing;
    return DecoratedBox(
      decoration: const BoxDecoration(color: ExampleTheme.videoBackground),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(child: _videoOutput.view()),
          if (showStageOverlay)
            Center(
              child: PlaybackCenterLoading(
                label: _stageStatusLabel,
                mode: _centerIndicatorMode,
              ),
            ),
        ],
      ),
    );
  }

  PlaybackCenterIndicatorMode get _centerIndicatorMode {
    if (_playbackState == _PlaybackViewState.connecting) {
      return PlaybackCenterIndicatorMode.loading;
    }

    if (_playbackState == _PlaybackViewState.failed) {
      return PlaybackCenterIndicatorMode.error;
    }

    if (_playbackState == _PlaybackViewState.idle && !_shouldKeepPlaying) {
      return PlaybackCenterIndicatorMode.error;
    }

    return PlaybackCenterIndicatorMode.loading;
  }

  Widget _buildOverlayGradient() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.black.withAlpha(117),
              Colors.transparent,
              Colors.black.withAlpha(153),
            ],
          ),
        ),
      ),
    );
  }
}
