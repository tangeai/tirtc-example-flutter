import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import 'demo_call_command.dart';
import 'widgets/downlink_metrics_overlay.dart';

const int _tiRtcErrorInvalidArgument = 6000;

final class DemoDownlinkSession {
  DemoDownlinkSession({TiRtcConn? connection})
      : _connection = connection ?? TiRtcConn(),
        _audioOutput = TiRtcAudioOutput(),
        _videoOutput = TiRtcVideoOutput(),
        _audioInput = TiRtcAudioInput(),
        _videoInput = TiRtcVideoInput();

  DemoDownlinkSession.localInputsOnly()
      : _connection = null,
        _audioOutput = null,
        _videoOutput = null,
        _audioInput = TiRtcAudioInput(),
        _videoInput = TiRtcVideoInput();

  TiRtcConn? _connection;
  final TiRtcAudioOutput? _audioOutput;
  final TiRtcVideoOutput? _videoOutput;
  final TiRtcAudioInput _audioInput;
  final TiRtcVideoInput _videoInput;
  final Set<TiRtcConn> _localAudioConnections = <TiRtcConn>{};
  final Set<TiRtcConn> _localVideoConnections = <TiRtcConn>{};
  bool _disposed = false;

  Widget buildVideoView() {
    return _videoOutput!.view();
  }

  Widget buildLocalPreview() {
    return _videoInput.preview();
  }

  void bindAcceptedConnection(TiRtcConn connection) {
    if (_connection != null) {
      throw StateError('connection already bound');
    }
    _connection = connection;
  }

  void setCommandCallback(TiRtcOnConnCommand? onCommand) {
    _connection?.onCommand = onCommand;
  }

  void bindCallbacks({
    required TiRtcOnConnStateChanged onConnectionStateChanged,
    required TiRtcOnAudioOutputStateChanged onAudioStateChanged,
    required TiRtcOnAudioOutputError onAudioError,
    required TiRtcOnVideoOutputStateChanged onVideoStateChanged,
    TiRtcOnVideoOutputRenderSizeChanged? onVideoRenderSizeChanged,
    required TiRtcOnVideoOutputError onVideoError,
    TiRtcOnConnCommand? onCommand,
    TiRtcOnInputStateChanged? onAudioInputStateChanged,
    TiRtcOnInputError? onAudioInputError,
    TiRtcOnInputStateChanged? onVideoInputStateChanged,
    TiRtcOnVideoInputActualConfigChanged? onVideoInputActualConfigChanged,
    TiRtcOnInputError? onVideoInputError,
  }) {
    final TiRtcConn? connection = _connection;
    if (connection != null) {
      connection.onStateChanged = onConnectionStateChanged;
      connection.onCommand = onCommand;
    }
    _audioOutput?.onStateChanged = onAudioStateChanged;
    _audioOutput?.onError = onAudioError;
    _videoOutput?.onStateChanged = onVideoStateChanged;
    _videoOutput?.onRenderSizeChanged = onVideoRenderSizeChanged;
    _videoOutput?.onError = onVideoError;
    _audioInput.onStateChanged = onAudioInputStateChanged;
    _audioInput.onError = onAudioInputError;
    _videoInput.onStateChanged = onVideoInputStateChanged;
    _videoInput.onActualConfigChanged = onVideoInputActualConfigChanged;
    _videoInput.onError = onVideoInputError;
  }

  void clearCallbacks() {
    final TiRtcConn? connection = _connection;
    if (connection != null) {
      connection.onStateChanged = null;
      connection.onCommand = null;
    }
    _audioOutput?.onStateChanged = null;
    _audioOutput?.onError = null;
    _videoOutput?.onStateChanged = null;
    _videoOutput?.onRenderSizeChanged = null;
    _videoOutput?.onError = null;
    _audioInput.onStateChanged = null;
    _audioInput.onError = null;
    _videoInput.onStateChanged = null;
    _videoInput.onActualConfigChanged = null;
    _videoInput.onError = null;
  }

  int connect({
    required String remoteId,
    required String token,
  }) {
    final TiRtcConn? connection = _connection;
    if (connection == null) {
      return _tiRtcErrorInvalidArgument;
    }
    return connection.connect(remoteId: remoteId, token: token);
  }

  int attachAudio({required int streamId}) {
    final TiRtcConn? connection = _connection;
    if (connection == null) {
      return _tiRtcErrorInvalidArgument;
    }
    final TiRtcAudioOutput? audioOutput = _audioOutput;
    if (audioOutput == null) {
      return _tiRtcErrorInvalidArgument;
    }
    return audioOutput.attach(connection: connection, streamId: streamId);
  }

  int setVideoOptions({required int decoderPreference}) {
    final TiRtcVideoOutput? videoOutput = _videoOutput;
    if (videoOutput == null) {
      return _tiRtcErrorInvalidArgument;
    }
    return videoOutput.setOptions(
      TiRtcVideoOutputOptions(decoderPreference: decoderPreference),
    );
  }

  int attachVideo({required int streamId}) {
    final TiRtcConn? connection = _connection;
    if (connection == null) {
      return _tiRtcErrorInvalidArgument;
    }
    final TiRtcVideoOutput? videoOutput = _videoOutput;
    if (videoOutput == null) {
      return _tiRtcErrorInvalidArgument;
    }
    return videoOutput.attach(connection: connection, streamId: streamId);
  }

  int sendCallCommand(DemoCallCommand command) {
    if (!command.valid) {
      return _tiRtcErrorInvalidArgument;
    }
    final TiRtcConn? connection = _connection;
    if (connection == null) {
      return _tiRtcErrorInvalidArgument;
    }
    return connection.sendCommand(
      commandId: demoCallCommandId,
      data: command.encode(),
    );
  }

  int sendCommand({
    required int commandId,
    required Uint8List payload,
  }) {
    final TiRtcConn? connection = _connection;
    if (connection == null) {
      return _tiRtcErrorInvalidArgument;
    }
    return connection.sendCommand(commandId: commandId, data: payload);
  }

  Future<int> prepareLocalInputs({
    TiRtcAudioInputOptions audioOptions = const TiRtcAudioInputOptions(),
    TiRtcVideoInputOptions videoOptions = const TiRtcVideoInputOptions(),
  }) async {
    int code = await _audioInput.setOptions(audioOptions);
    if (code != 0) {
      return code;
    }
    code = await _videoInput.setOptions(videoOptions);
    if (code != 0) {
      return code;
    }
    return 0;
  }

  Future<int> startLocalInputs({
    TiRtcAudioInputOptions audioOptions = const TiRtcAudioInputOptions(),
    TiRtcVideoInputOptions videoOptions = const TiRtcVideoInputOptions(),
  }) async {
    final int prepareCode = await prepareLocalInputs(
      audioOptions: audioOptions,
      videoOptions: videoOptions,
    );
    if (prepareCode != 0) {
      return prepareCode;
    }
    int code = await _audioInput.start();
    if (code != 0) {
      return code;
    }
    code = await _videoInput.start();
    if (code != 0) {
      await _audioInput.stop();
      return code;
    }
    return 0;
  }

  Future<int> attachLocalInputs({
    required int audioStreamId,
    required int videoStreamId,
  }) async {
    final TiRtcConn? connection = _connection;
    if (connection == null) {
      return _tiRtcErrorInvalidArgument;
    }
    return attachLocalInputsToConnection(
      connection,
      audioStreamId: audioStreamId,
      videoStreamId: videoStreamId,
    );
  }

  Future<int> attachLocalInputsToConnection(
    TiRtcConn connection, {
    required int audioStreamId,
    required int videoStreamId,
  }) async {
    int code = await _audioInput.attach(connection: connection, streamId: audioStreamId);
    if (code != 0) {
      return code;
    }
    _localAudioConnections.add(connection);
    code = await _videoInput.attach(connection: connection, streamId: videoStreamId);
    if (code != 0) {
      await _audioInput.detach(connection: connection);
      _localAudioConnections.remove(connection);
      return code;
    }
    _localVideoConnections.add(connection);
    return 0;
  }

  Future<void> detachAndStopLocalInputs() async {
    await detachLocalInputsFromAllConnections();
    await _videoInput.stop();
    await _audioInput.stop();
  }

  Future<void> stopAndDetachLocalInputs() async {
    await _videoInput.stop();
    await _audioInput.stop();
    await detachLocalInputsFromAllConnections();
  }

  TiRtcAudioOutputState get audioState => _audioOutput?.state ?? TiRtcAudioOutputState.idle;

  TiRtcVideoOutputState get videoState => _videoOutput?.state ?? TiRtcVideoOutputState.idle;

  TiRtcInputState get audioInputState => _audioInput.state;

  TiRtcInputState get videoInputState => _videoInput.state;

  Size? get localVideoSize => _videoInput.outputSize;

  int? get localVideoFps => _videoInput.outputFps;

  Size? get renderSize => _videoOutput?.renderSize;

  bool get hasBoundConnection => _connection != null;

  void detachAudio() {
    _audioOutput?.detach();
  }

  void disconnectConnection() {
    _connection?.disconnect();
  }

  Future<void> detachLocalInputsFromBoundConnection() async {
    final TiRtcConn? connection = _connection;
    if (connection != null) {
      await detachLocalInputsFromConnection(connection);
    }
  }

  Future<void> detachLocalInputsFromConnection(TiRtcConn connection) async {
    if (_localVideoConnections.remove(connection)) {
      await _videoInput.detach(connection: connection);
    }
    if (_localAudioConnections.remove(connection)) {
      await _audioInput.detach(connection: connection);
    }
  }

  Future<void> detachLocalInputsFromAllConnections() async {
    final List<TiRtcConn> videoConnections = List<TiRtcConn>.of(_localVideoConnections);
    _localVideoConnections.clear();
    for (final TiRtcConn connection in videoConnections) {
      await _videoInput.detach(connection: connection);
    }

    final List<TiRtcConn> audioConnections = List<TiRtcConn>.of(_localAudioConnections);
    _localAudioConnections.clear();
    for (final TiRtcConn connection in audioConnections) {
      await _audioInput.detach(connection: connection);
    }
  }

  void releaseBoundConnectionIfSame(TiRtcConn connection) {
    if (!identical(_connection, connection)) {
      return;
    }
    releaseBoundConnection();
  }

  void releaseBoundConnection() {
    _connection?.dispose();
    _connection = null;
  }

  void disconnect({required String reason}) {
    TiRtcLogging.i('flutter_example', 'downlink_stop_requested reason=$reason');
    unawaited(detachAndStopLocalInputs());
    _videoOutput?.detach();
    _audioOutput?.detach();
    _connection?.disconnect();
  }

  DownlinkMetricsOverlayModel? readMetricsOverlay({
    required int requestedDecoderPreference,
  }) {
    final TiRtcConn? connection = _connection;
    if (connection == null) {
      return null;
    }
    final TiRtcConnMetricsResult connResult = connection.getMetricsSnapshot();
    final TiRtcVideoOutput? videoOutput = _videoOutput;
    final TiRtcAudioOutput? audioOutput = _audioOutput;
    if (videoOutput == null || audioOutput == null) {
      return null;
    }
    final TiRtcVideoOutputMetricsResult videoResult = videoOutput.getMetricsSnapshot();
    final TiRtcAudioOutputMetricsResult audioResult = audioOutput.getMetricsSnapshot();
    if (connResult.code != 0 || videoResult.code != 0 || audioResult.code != 0) {
      return null;
    }

    final TiRtcConnMetricsSnapshot? connSnapshot = connResult.snapshot;
    final TiRtcVideoOutputMetricsSnapshot? videoSnapshot = videoResult.snapshot;
    final TiRtcAudioOutputMetricsSnapshot? audioSnapshot = audioResult.snapshot;
    if (connSnapshot == null || videoSnapshot == null || audioSnapshot == null) {
      return null;
    }

    final TiRtcAudioOutputDebugSnapshotResult audioDebugResult = audioOutput.getDebugSnapshot();
    final TiRtcVideoOutputDebugSnapshotResult videoDebugResult = videoOutput.getDebugSnapshot();
    final TiRtcAudioOutputDebugSnapshot? audioDebugSnapshot =
        audioDebugResult.code == 0 ? audioDebugResult.snapshot : null;
    final TiRtcVideoOutputDebugSnapshot? videoDebugSnapshot =
        videoDebugResult.code == 0 ? videoDebugResult.snapshot : null;

    return DownlinkMetricsOverlayModel(
      connectDurationMs: connSnapshot.connectDurationMs,
      firstFrameDurationMs: videoSnapshot.startup.firstFrameDurationMs,
      sessionStutterRatio: videoSnapshot.stutter.sessionStutterRatio,
      sessionStutterCount: videoSnapshot.stutter.sessionStutterCount,
      sessionStutterPeakMs: videoSnapshot.stutter.sessionStutterPeakMs,
      videoWidth: videoDebugSnapshot?.width,
      videoHeight: videoDebugSnapshot?.height,
      videoCodec: videoDebugSnapshot?.codec,
      audioCodec: audioDebugSnapshot?.codec,
      requestedDecoderPreference: requestedDecoderPreference,
      resolvedDecoderBackend: videoDebugSnapshot?.resolvedDecoderBackend,
      audioInputBitrateKbps: audioSnapshot.inputBitrateKbps,
      audioInputPacketRate: audioSnapshot.inputPacketRate,
      audioRenderCallbackRate: audioSnapshot.renderCallbackRate,
      audioRateWindowDurationMs: audioSnapshot.rateWindowDurationMs,
      videoInputBitrateKbps: videoSnapshot.inputBitrateKbps,
      videoInputFps: videoSnapshot.inputFps,
      videoDecodedFps: videoSnapshot.decodedFps,
      videoRenderFps: videoSnapshot.renderFps,
      videoRateWindowDurationMs: videoSnapshot.rateWindowDurationMs,
    );
  }

  TiRtcVideoOutputMetricsResult videoMetrics() {
    final TiRtcVideoOutput? videoOutput = _videoOutput;
    if (videoOutput == null) {
      return (code: _tiRtcErrorInvalidArgument, snapshot: null);
    }
    return videoOutput.getMetricsSnapshot();
  }

  void dispose() {
    unawaited(disposeAsync());
  }

  Future<void> disposeAsync() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _videoInput.dispose();
    await _audioInput.dispose();
    _videoOutput?.dispose();
    _audioOutput?.dispose();
    _connection?.dispose();
    _connection = null;
  }
}
