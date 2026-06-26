import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import 'demo_configuration.dart';
import 'demo_downlink_session.dart';
import 'demo_echo_command.dart';
import 'demo_stream_message.dart';
import 'demo_test_hooks.dart';
import 'widgets/command_panel_model.dart';

typedef DemoDeviceServerPermissionRequest = Future<bool> Function();

final class DemoDeviceServerController extends ChangeNotifier {
  static const Duration _performanceMeasureHealthInterval = Duration(seconds: 1);
  static const Duration _serviceStartTimeout = Duration(seconds: 10);
  static const Duration _serviceConnectTimeout = Duration(seconds: 150);
  static const int _commandSendInvalidState = 6000;

  DemoDeviceServerController({
    required this.configuration,
    this.markerSink,
    this.performanceMarkerSink,
    this.renderWindowSeconds,
    this.requestPermissions,
    this.runtimeAlreadyInitialized = false,
    this.showLocalPreview = true,
  });

  final DemoDeviceServerConfiguration configuration;
  final DemoAutomationMarkerSink? markerSink;
  final DemoPerformanceMarkerSink? performanceMarkerSink;
  final int? renderWindowSeconds;
  final DemoDeviceServerPermissionRequest? requestPermissions;
  final bool runtimeAlreadyInitialized;
  final bool showLocalPreview;

  DemoDownlinkSession? _session;
  TiRtcConnService? _service;
  final DemoEchoCommandResponder _echoResponder = DemoEchoCommandResponder();
  late final DemoStreamMessageSender _streamMessageSender = DemoStreamMessageSender(
    streamId: DemoDeviceServerConfiguration.defaultVideoStreamId,
    onSent: _handleStreamMessageSent,
  );
  AutomationCommandProbe? _commandProbe;
  final Set<TiRtcConn> _acceptedConnections = <TiRtcConn>{};
  final Map<TiRtcConn, int> _acceptedConnectionSessionIndexes = <TiRtcConn, int>{};
  final Set<int> _streamMessageMarkerSessionIndexes = <int>{};
  List<DemoCommandPanelEvent> _commandEvents = <DemoCommandPanelEvent>[];
  int _nextAcceptedSessionIndex = 0;
  bool _commandConnected = false;
  bool _started = false;
  bool _terminal = false;
  bool _localPreviewVisible = false;
  String _stageLabel = '初始化中';
  String? _failureStage;
  String? _failureMessage;
  int? _failureErrorCode;
  String? _failureNativeMessage;
  Completer<void>? _firstLocalInputsStarted;

  DemoDownlinkSession? get session => _session;

  bool get localPreviewVisible => _localPreviewVisible;

  bool get commandConnected => _commandConnected;

  List<DemoCommandPanelEvent> get commandEvents => List<DemoCommandPanelEvent>.unmodifiable(_commandEvents);

  String get stageLabel => _stageLabel;

  String? get failureStage => _failureStage;

  String? get failureMessage => _failureMessage;

  int? get failureErrorCode => _failureErrorCode;

  String? get failureNativeMessage => _failureNativeMessage;

  bool get failed => _failureMessage != null;

  Widget buildLocalPreview() {
    return _session?.buildLocalPreview() ?? const SizedBox.expand();
  }

  Future<int> sendCommand(int commandId, Uint8List payload) async {
    final TiRtcConn? connection = _acceptedConnections.isEmpty ? null : _acceptedConnections.first;
    final int code = connection?.sendCommand(commandId: commandId, data: payload) ?? _commandSendInvalidState;
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

  Future<int> start() async {
    if (_started) {
      return 0;
    }
    _started = true;
    _commandEvents = <DemoCommandPanelEvent>[];
    _setCommandConnected(false);
    _setStage('初始化中');

    if (!runtimeAlreadyInitialized) {
      final int initializeCode = await TiRtc.initialize(
        TiRtcInitOptions(
          appId: '',
          endpoint: configuration.endpoint,
          consoleLogEnabled: configuration.settings.consoleLogEnabled,
        ),
      );
      if (initializeCode != 0) {
        _fail(
          failureStage: 'runtime_init',
          message: 'runtime initialize failed',
          errorCode: initializeCode,
        );
        return initializeCode;
      }
    }
    markerSink?.passed('runtime_initialized', payload: <String, Object?>{
      'endpoint': configuration.endpoint.isEmpty ? null : configuration.endpoint,
      'app_id_present': false,
    });
    performanceMarkerSink?.passed('perf_runtime_initialized', payload: <String, Object?>{
      'endpoint': configuration.endpoint.isEmpty ? null : configuration.endpoint,
      'device_id_present': configuration.deviceId.isNotEmpty,
    });
    _session = DemoDownlinkSession.localInputsOnly();
    _firstLocalInputsStarted = Completer<void>();

    if (requestPermissions != null && !await requestPermissions!()) {
      _fail(
        failureStage: 'capture_permission',
        message: 'camera or microphone permission denied',
      );
      return 1;
    }

    _setStage('准备本地采集');
    final TiRtcAudioInputOptions audioOptions = _audioInputOptions();
    final TiRtcVideoInputOptions videoOptions = _videoInputOptions();
    final int prepareLocalCode = await _session!.prepareLocalInputs(
      audioOptions: audioOptions,
      videoOptions: videoOptions,
    );
    if (prepareLocalCode != 0) {
      _fail(
        failureStage: 'local_input_prepare',
        message: 'local input prepare failed',
        errorCode: prepareLocalCode,
      );
      return prepareLocalCode;
    }

    _setStage('启动本地预览');
    final int startVideoCode = await _session!.startLocalVideo();
    if (startVideoCode != 0) {
      _fail(
        failureStage: 'local_input_start',
        message: 'local video input start failed',
        errorCode: startVideoCode,
      );
      return startVideoCode;
    }
    final int? actualWidth = _session!.localVideoSize?.width.round();
    final int? actualHeight = _session!.localVideoSize?.height.round();
    final int? actualFps = _session!.localVideoFps;
    if (performanceMarkerSink != null &&
        (!_positiveInt(actualWidth) || !_positiveInt(actualHeight) || !_positiveInt(actualFps))) {
      _fail(
        failureStage: 'local_input_start',
        message: 'local input actual config unavailable',
      );
      return 1;
    }
    _localPreviewVisible = showLocalPreview;
    notifyListeners();

    final Completer<void> serviceStarted = Completer<void>();
    final Completer<_DeviceServerServiceFailure> serviceFailure = Completer<_DeviceServerServiceFailure>();
    final TiRtcConnService service = TiRtcConnService(
      TiRtcConnServiceConfig(
        deviceId: configuration.deviceId,
        deviceSecretKey: configuration.deviceSecretKey,
      ),
    )
      ..onStarted = () {
        TiRtcLogging.i('flutter_example', 'server_service_started');
        _complete(serviceStarted);
      }
      ..onConnected = (TiRtcConn connection) {
        TiRtcLogging.i('flutter_example', 'server_service_connected');
        unawaited(_handleAcceptedConnection(connection));
      }
      ..onError = (int code, String? message) {
        TiRtcLogging.w(
          'flutter_example',
          'server_service_error code=$code message=${message ?? ''}',
        );
        final _DeviceServerServiceFailure failure = _DeviceServerServiceFailure(code: code, message: message);
        if (!serviceStarted.isCompleted) {
          if (!serviceFailure.isCompleted) {
            serviceFailure.complete(failure);
          }
          return;
        }
        _fail(
          failureStage: 'service_runtime',
          message: _serviceFailureMessage(failure),
          errorCode: failure.code,
          nativeMessage: failure.message,
        );
      };

    _service = service;
    _setStage('启动连接服务');
    final int startCode = service.start();
    TiRtcLogging.i('flutter_example', 'server_service_start_return code=$startCode');
    if (startCode != 0) {
      service.dispose();
      if (identical(_service, service)) {
        _service = null;
      }
      _fail(
        failureStage: 'service_start',
        message: 'conn service start failed',
        errorCode: startCode,
      );
      return startCode;
    }
    if (!await _waitForServerStage(
      serviceStarted.future,
      serviceFailure.future,
      failureStage: 'service_start',
      timeout: _serviceStartTimeout,
      timeoutMessage: '连接服务启动超时。',
    )) {
      return 1;
    }
    if (_terminal) {
      return 1;
    }
    markerSink?.passed('service_started', payload: <String, Object?>{
      'device_id_present': configuration.deviceId.isNotEmpty,
    });
    performanceMarkerSink?.passed('perf_service_started', payload: <String, Object?>{
      'device_id_present': configuration.deviceId.isNotEmpty,
    });

    final int? seconds = renderWindowSeconds;
    if (seconds != null &&
        !await _waitForServerStage(
          _firstLocalInputsStarted!.future,
          serviceFailure.future,
          failureStage: 'service_connected',
          timeout: _serviceConnectTimeout,
          timeoutMessage: '等待远端连接并启动本地采集超时。',
        )) {
      return 1;
    }
    if (_terminal) {
      return 1;
    }

    _setStage('运行中');

    if (seconds == null) {
      return 0;
    }
    performanceMarkerSink?.passed('perf_measure_window_started', payload: <String, Object?>{
      'duration_seconds': seconds,
    });
    final Stopwatch measureTimer = Stopwatch()..start();
    int sampleIndex = 0;
    while (measureTimer.elapsed < Duration(seconds: seconds)) {
      final bool healthy = _emitPerformanceHealthSample(sampleIndex);
      if (!healthy) {
        _fail(failureStage: 'render_window', message: 'local input stopped during render window');
        return 1;
      }
      sampleIndex += 1;
      final Duration remaining = Duration(seconds: seconds) - measureTimer.elapsed;
      await Future<void>.delayed(
        remaining < _performanceMeasureHealthInterval ? remaining : _performanceMeasureHealthInterval,
      );
    }
    markerSink?.passed('render_window_completed', payload: <String, Object?>{
      'audio_error_count': 0,
      'video_error_count': 0,
      'audio_input_state': _session!.audioInputState.name,
      'video_input_state': _session!.videoInputState.name,
      'local_preview_visible': _localPreviewVisible,
      'remote_small_window_state': 'not_attached',
    });
    performanceMarkerSink?.passed('perf_measure_window_completed', payload: <String, Object?>{
      'audio_input_state': _session!.audioInputState.name,
      'video_input_state': _session!.videoInputState.name,
      'local_preview_visible': _localPreviewVisible,
    });

    if (markerSink != null) {
      final ({int code, String? logId}) upload = await TiRtcLogging.upload();
      if (upload.code != 0 || upload.logId == null || upload.logId!.isEmpty) {
        _fail(
          failureStage: 'log_upload',
          message: 'log upload failed',
          errorCode: upload.code,
        );
        return upload.code;
      }
      markerSink?.passed('log_upload_completed', payload: <String, Object?>{
        'log_id': upload.logId,
        'code': upload.code,
      });
    }

    final int releaseCode = await release(reason: 'automation_teardown');
    if (releaseCode != 0) {
      _fail(
        failureStage: 'teardown',
        message: 'server resources release failed',
        errorCode: releaseCode,
      );
      return releaseCode;
    }
    final int shutdownCode = await _shutdownRuntimeAfterDisposal();
    if (shutdownCode != 0) {
      _fail(
        failureStage: 'teardown',
        message: 'runtime shutdown failed',
        errorCode: shutdownCode,
      );
      return shutdownCode;
    }
    markerSink?.passed('teardown_completed', payload: <String, Object?>{
      'returned_to_configure': true,
    });
    performanceMarkerSink?.passed('perf_teardown_completed', payload: <String, Object?>{
      'returned_to_configure': true,
    });
    return 0;
  }

  Future<int> release({required String reason}) async {
    TiRtcLogging.i('flutter_example', 'server_release_requested reason=$reason');
    if (_localPreviewVisible) {
      _localPreviewVisible = false;
      notifyListeners();
      await WidgetsBinding.instance.endOfFrame;
    }
    TiRtcLogging.i('flutter_example', 'server_release_stop_inputs_start reason=$reason');
    await _session?.detachAndStopLocalInputs();
    TiRtcLogging.i('flutter_example', 'server_release_stop_inputs_done reason=$reason');
    _releaseAcceptedConnections(reason: reason);
    TiRtcLogging.i('flutter_example', 'server_release_connection_released reason=$reason');

    final TiRtcConnService? service = _service;
    int stopCode = 0;
    if (service != null) {
      stopCode = service.stop();
      service.dispose();
      TiRtcLogging.i('flutter_example', 'server_release_service_stopped reason=$reason code=$stopCode');
      if (identical(_service, service)) {
        _service = null;
      }
    }
    await _session?.disposeAsync();
    _session = null;
    _localPreviewVisible = false;
    notifyListeners();
    TiRtcLogging.i('flutter_example', 'server_release_done reason=$reason code=$stopCode');
    return stopCode;
  }

  Future<int> shutdownRuntime() {
    return _shutdownRuntimeAfterDisposal();
  }

  void _setStage(String label) {
    _stageLabel = label;
    notifyListeners();
  }

  void _fail({
    required String failureStage,
    required String message,
    int? errorCode,
    String? nativeMessage,
  }) {
    if (_terminal) {
      return;
    }
    _terminal = true;
    _failureStage = failureStage;
    _failureMessage = message;
    _failureErrorCode = errorCode;
    _failureNativeMessage = nativeMessage;
    TiRtcLogging.w(
      'flutter_example',
      'server_failed stage=$failureStage message=$message '
          'errorCode=${errorCode ?? 0} nativeMessage=${nativeMessage ?? ''}',
    );
    markerSink?.failure(
      failureStage: failureStage,
      message: message,
      errorCode: errorCode,
    );
    final Completer<void>? firstLocalInputsStarted = _firstLocalInputsStarted;
    if (firstLocalInputsStarted != null) {
      _complete(firstLocalInputsStarted);
    }
    performanceMarkerSink?.failure(
      errorStage: _performanceFailureStage(failureStage),
      errorCode: _performanceFailureCode(failureStage),
      errorMessage: message,
    );
    unawaited(release(reason: 'device_server_failure').whenComplete(_shutdownRuntimeAfterDisposal));
    notifyListeners();
  }

  Future<bool> _waitForServerStage(
    Future<void> future,
    Future<_DeviceServerServiceFailure> failure, {
    required String failureStage,
    Duration? timeout,
    String? timeoutMessage,
  }) async {
    final List<Future<Object>> waiters = <Future<Object>>[
      future.then<Object>((_) => true),
      failure.then<Object>((_DeviceServerServiceFailure failure) => failure),
    ];
    if (timeout != null) {
      waiters.add(Future<void>.delayed(timeout).then<Object>((_) => const _DeviceServerStageTimeout()));
    }
    final Object result = await Future.any<Object>(<Future<Object>>[
      ...waiters,
    ]);
    if (result == true) {
      return true;
    }
    if (result is _DeviceServerServiceFailure) {
      _fail(
        failureStage: failureStage,
        message: _serviceFailureMessage(result),
        errorCode: result.code,
        nativeMessage: result.message,
      );
      return false;
    }
    if (result is _DeviceServerStageTimeout) {
      _fail(
        failureStage: failureStage,
        message: timeoutMessage ?? '等待超时。',
      );
      return false;
    }
    return false;
  }

  Future<void> _handleAcceptedConnection(TiRtcConn connection) async {
    if (_terminal) {
      connection.dispose();
      return;
    }
    final DemoDownlinkSession? session = _session;
    if (session == null) {
      connection.dispose();
      return;
    }

    _acceptedConnections.add(connection);
    _nextAcceptedSessionIndex += 1;
    final int sessionIndex = _nextAcceptedSessionIndex;
    _acceptedConnectionSessionIndexes[connection] = sessionIndex;
    connection.onStateChanged = (TiRtcConnState state, int errorCode) {
      TiRtcLogging.i(
        'flutter_example',
        'server_connection_state_changed state=${state.name} errorCode=$errorCode',
      );
      if (state == TiRtcConnState.disconnected) {
        unawaited(_handleAcceptedConnectionDisconnected(session, connection, errorCode));
      }
    };
    connection.onCommand = (int commandId, Uint8List payload) {
      _handleCommand(connection, commandId, payload);
    };
    markerSink?.passed('service_connected', payload: <String, Object?>{
      'conn_handle_present': true,
      'session_index': sessionIndex,
      'active_connections': _acceptedConnections.length,
    });
    performanceMarkerSink?.passed('perf_service_connected', payload: <String, Object?>{
      'conn_handle_present': true,
      'active_connections': _acceptedConnections.length,
    });

    final int attachLocalCode = await session.attachLocalInputsToConnection(
      connection,
      audioStreamId: DemoDeviceServerConfiguration.defaultAudioStreamId,
      videoStreamId: DemoDeviceServerConfiguration.defaultVideoStreamId,
    );
    if (attachLocalCode != 0) {
      _acceptedConnections.remove(connection);
      _acceptedConnectionSessionIndexes.remove(connection);
      connection.dispose();
      _fail(
        failureStage: 'local_input_attach',
        message: 'local input attach failed',
        errorCode: attachLocalCode,
      );
      return;
    }
    markerSink?.passed('local_inputs_attached', payload: <String, Object?>{
      'audio_stream_id': DemoDeviceServerConfiguration.defaultAudioStreamId,
      'video_stream_id': DemoDeviceServerConfiguration.defaultVideoStreamId,
      'session_index': sessionIndex,
      'active_connections': _acceptedConnections.length,
    });
    TiRtcLogging.i(
      'flutter_example',
      'server_local_inputs_attached audio_stream_id=${DemoDeviceServerConfiguration.defaultAudioStreamId} '
          'video_stream_id=${DemoDeviceServerConfiguration.defaultVideoStreamId} '
          'active_connections=${_acceptedConnections.length}',
    );
    performanceMarkerSink?.passed('perf_local_inputs_attached', payload: <String, Object?>{
      'audio_stream_id': DemoDeviceServerConfiguration.defaultAudioStreamId,
      'video_stream_id': DemoDeviceServerConfiguration.defaultVideoStreamId,
      'active_connections': _acceptedConnections.length,
    });

    final int startAudioCode = await session.startLocalAudio();
    if (startAudioCode != 0) {
      _acceptedConnections.remove(connection);
      _acceptedConnectionSessionIndexes.remove(connection);
      await session.detachLocalInputsFromConnection(connection);
      connection.dispose();
      _fail(
        failureStage: 'local_input_start',
        message: 'local audio input start failed',
        errorCode: startAudioCode,
      );
      return;
    }

    final Map<String, Object?> localInputsStartedPayload = <String, Object?>{
      'audio_input_started': session.audioInputState == TiRtcInputState.running,
      'video_input_started': session.videoInputState == TiRtcInputState.running,
      'native_capture_owner': _nativeCaptureOwner(),
      'requested_audio_codec': configuration.audioCodec.name,
      'requested_audio_sample_rate_hz': configuration.audioSampleRate.hertz,
      'requested_audio_channels': configuration.audioChannels.count,
      'requested_video_codec': configuration.videoCodec.name,
      'requested_encoder_preference': configuration.encoderPreference.name,
      'requested_width': DemoDeviceServerConfiguration.fixedVideoWidth,
      'requested_height': DemoDeviceServerConfiguration.fixedVideoHeight,
      'requested_fps': DemoDeviceServerConfiguration.fixedVideoFps,
      'actual_width': session.localVideoSize?.width.round(),
      'actual_height': session.localVideoSize?.height.round(),
      'actual_fps': session.localVideoFps,
      'actual_encoder_backend':
          configuration.encoderPreference == DemoDeviceEncoderPreference.hardware ? 'hardware' : 'software',
      'fallback_applied': false,
    };
    markerSink?.passed('local_inputs_started', payload: localInputsStartedPayload);
    performanceMarkerSink?.passed('perf_local_inputs_started', payload: <String, Object?>{
      'audio_input_started': localInputsStartedPayload['audio_input_started'],
      'video_input_started': localInputsStartedPayload['video_input_started'],
      'native_capture_owner': localInputsStartedPayload['native_capture_owner'],
    });
    performanceMarkerSink?.passed('perf_encoder_backend_resolved', payload: <String, Object?>{
      'backend_proof_source': 'android_video_input_start_result',
      'requested_encoder_preference': configuration.encoderPreference.name,
      'actual_encoder_backend': localInputsStartedPayload['actual_encoder_backend'],
      'video_codec': 'h264',
      'requested_width': DemoDeviceServerConfiguration.fixedVideoWidth,
      'requested_height': DemoDeviceServerConfiguration.fixedVideoHeight,
      'requested_fps': DemoDeviceServerConfiguration.fixedVideoFps,
      'actual_config_width': localInputsStartedPayload['actual_width'],
      'actual_config_height': localInputsStartedPayload['actual_height'],
      'actual_config_fps': localInputsStartedPayload['actual_fps'],
    });
    final Completer<void>? firstLocalInputsStarted = _firstLocalInputsStarted;
    if (firstLocalInputsStarted != null) {
      _complete(firstLocalInputsStarted);
    }
    _setCommandConnected(true);

    if (markerSink != null && !await _runCommandProbe(connection)) {
      return;
    }
    if (_terminal || !identical(_session, session) || !_acceptedConnections.contains(connection)) {
      return;
    }
    _streamMessageSender.start(connection, sessionIndex: sessionIndex);
  }

  Future<void> _handleAcceptedConnectionDisconnected(
    DemoDownlinkSession session,
    TiRtcConn connection,
    int errorCode,
  ) async {
    if (!identical(_session, session)) {
      return;
    }
    TiRtcLogging.i(
      'flutter_example',
      'server_connection_disconnected errorCode=$errorCode active_before=${_acceptedConnections.length}',
    );
    _acceptedConnections.remove(connection);
    final int? sessionIndex = _acceptedConnectionSessionIndexes.remove(connection);
    if (sessionIndex != null) {
      _streamMessageMarkerSessionIndexes.remove(sessionIndex);
    }
    _setCommandConnected(_acceptedConnections.isNotEmpty);
    _streamMessageSender.stop(connection);
    await session.stopLocalAudio();
    await session.detachLocalInputsFromConnection(connection);
    connection.onStateChanged = null;
    connection.onCommand = null;
    connection.dispose();
  }

  void _handleStreamMessageSent(DemoStreamMessageSendEvent event) {
    if (event.resultCode != 0 ||
        !event.periodicSendOk ||
        _streamMessageMarkerSessionIndexes.contains(event.sessionIndex)) {
      return;
    }
    _streamMessageMarkerSessionIndexes.add(event.sessionIndex);
    markerSink?.passed('stream_message_sent', payload: <String, Object?>{
      'session_index': event.sessionIndex,
      'stream_id': event.streamId,
      'payload_epoch_seconds': event.epochSeconds,
      'payload_bytes': event.payloadBytes,
      'payload_hash': event.payloadHash,
      'result_code': event.resultCode,
      'sent_count': event.sentCount,
      'periodic_send_ok': event.periodicSendOk,
    });
  }

  Future<bool> _runCommandProbe(TiRtcConn connection) async {
    final AutomationCommandProbe probe = AutomationCommandProbe();
    _commandProbe = probe;
    final AutomationCommandProbeResult result = await probe.run(
      sendCommand: ({
        required int commandId,
        required Uint8List payload,
      }) =>
          _sendProbeCommand(connection, commandId, payload),
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
    markerSink?.passed('command_echo_completed', payload: <String, Object?>{
      'command_id': result.commandId,
      'payload_text': result.payloadText,
      'payload_bytes': result.payloadBytes,
    });
    return true;
  }

  int _sendProbeCommand(TiRtcConn connection, int commandId, Uint8List payload) {
    final int code = connection.sendCommand(commandId: commandId, data: payload);
    _echoResponder.trackLocalSend(
      commandId: commandId,
      payload: payload,
      resultCode: code,
    );
    return code;
  }

  void _handleCommand(TiRtcConn connection, int commandId, Uint8List payload) {
    _appendCommandEvent(
      DemoCommandPanelEvent(
        direction: DemoCommandEventDirection.received,
        commandId: commandId,
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
    _commandProbe?.handleCommand(commandId, payload);
    final int? echoCode = _echoResponder.handleReceived(
      commandId: commandId,
      payload: payload,
      sendCommand: (int commandId, Uint8List payload) => connection.sendCommand(commandId: commandId, data: payload),
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

  void _appendCommandEvent(DemoCommandPanelEvent event) {
    _commandEvents = trimDemoCommandEvents(<DemoCommandPanelEvent>[..._commandEvents, event]);
    notifyListeners();
  }

  void _setCommandConnected(bool connected) {
    if (_commandConnected == connected) {
      return;
    }
    _commandConnected = connected;
    notifyListeners();
  }

  void _releaseAcceptedConnections({required String reason}) {
    final List<TiRtcConn> connections = List<TiRtcConn>.of(_acceptedConnections);
    _acceptedConnections.clear();
    _acceptedConnectionSessionIndexes.clear();
    _streamMessageMarkerSessionIndexes.clear();
    _setCommandConnected(false);
    _streamMessageSender.stopAll();
    for (final TiRtcConn connection in connections) {
      connection.onStateChanged = null;
      connection.onCommand = null;
      connection.dispose();
    }
    TiRtcLogging.i(
      'flutter_example',
      'server_release_accepted_connections_done reason=$reason count=${connections.length}',
    );
  }

  void _complete(Completer<void> completer) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  TiRtcVideoInputOptions _videoInputOptions() {
    return TiRtcVideoInputOptions(
      codec: switch (configuration.videoCodec) {
        DemoDeviceVideoCodec.h265 => TiRtcVideoCodec.h265,
        DemoDeviceVideoCodec.mjpeg => TiRtcVideoCodec.mjpeg,
        DemoDeviceVideoCodec.h264 => TiRtcVideoCodec.h264,
      },
      width: DemoDeviceServerConfiguration.fixedVideoWidth,
      height: DemoDeviceServerConfiguration.fixedVideoHeight,
      frameRate: TiRtcVideoFrameRate.fps15,
      bitrateKbps: DemoDeviceServerConfiguration.fixedVideoBitrateKbps,
      cameraFacing: switch (configuration.cameraFacing) {
        DemoDeviceCameraFacing.front => TiRtcCameraFacing.front,
        DemoDeviceCameraFacing.back => TiRtcCameraFacing.back,
      },
      encoderPreference: switch (configuration.encoderPreference) {
        DemoDeviceEncoderPreference.hardware => TiRtcVideoEncoderPreference.hardware,
        DemoDeviceEncoderPreference.software => TiRtcVideoEncoderPreference.software,
      },
    );
  }

  TiRtcAudioInputOptions _audioInputOptions() {
    return TiRtcAudioInputOptions(
      codec: switch (configuration.audioCodec) {
        DemoDeviceAudioCodec.g711a => TiRtcAudioCodec.g711a,
        DemoDeviceAudioCodec.aac => TiRtcAudioCodec.aac,
        DemoDeviceAudioCodec.pcm => TiRtcAudioCodec.pcm,
      },
      sampleRate: switch (configuration.audioSampleRate) {
        DemoDeviceAudioSampleRate.rate8k => TiRtcAudioSampleRate.rate8k,
        DemoDeviceAudioSampleRate.rate16k => TiRtcAudioSampleRate.rate16k,
      },
      channels: switch (configuration.audioChannels) {
        DemoDeviceAudioChannelCount.mono => TiRtcAudioChannelCount.mono,
      },
    );
  }

  Future<int> _shutdownRuntimeAfterDisposal() async {
    int code = TiRtc.shutdown();
    for (int attempt = 0; attempt < 10 && code == 1007; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      code = TiRtc.shutdown();
    }
    return code;
  }

  String _nativeCaptureOwner() {
    if (Platform.isAndroid) {
      return 'android_sdk';
    }
    if (Platform.operatingSystem == 'ohos') {
      return 'runtime_ohos';
    }
    return 'darwin_sdk';
  }

  bool _positiveInt(int? value) {
    return value != null && value > 0;
  }

  String _serviceFailureMessage(_DeviceServerServiceFailure failure) {
    final String? nativeMessage = failure.message;
    if (nativeMessage == null || nativeMessage.trim().isEmpty) {
      return '连接服务失败。';
    }
    return '连接服务失败：${nativeMessage.trim()}';
  }

  bool _emitPerformanceHealthSample(int sampleIndex) {
    final bool healthy = _session != null &&
        _session!.audioInputState == TiRtcInputState.running &&
        _session!.videoInputState == TiRtcInputState.running &&
        (!showLocalPreview || _localPreviewVisible);
    performanceMarkerSink?.passed('perf_measure_window_sample', payload: <String, Object?>{
      'sample_index': sampleIndex,
      'valid_for_metrics': healthy,
      'audio_input_state': _session?.audioInputState.name,
      'video_input_state': _session?.videoInputState.name,
      'local_preview_visible': _localPreviewVisible,
      'local_preview_required': showLocalPreview,
    });
    return healthy;
  }

  String _performanceFailureStage(String failureStage) {
    return switch (failureStage) {
      'runtime_init' => 'runtime_init',
      'service_start' || 'service_connected' || 'service_runtime' => 'counterpart',
      'local_input_prepare' || 'local_input_start' => 'backend_proof',
      'local_input_attach' => 'media_start',
      'render_window' => 'measure_window',
      'teardown' => 'teardown',
      _ => 'runtime_init',
    };
  }

  String _performanceFailureCode(String failureStage) {
    return switch (failureStage) {
      'capture_permission' => 'permission_denied',
      'service_start' || 'service_connected' || 'service_runtime' => 'counterpart_timeout',
      'local_input_prepare' || 'local_input_start' => 'backend_unavailable',
      'render_window' => 'marker_timeout',
      'teardown' => 'teardown_failed',
      _ => 'runtime_error',
    };
  }
}

final class _DeviceServerStageTimeout {
  const _DeviceServerStageTimeout();
}

final class _DeviceServerServiceFailure {
  const _DeviceServerServiceFailure({
    required this.code,
    required this.message,
  });

  final int code;
  final String? message;
}
