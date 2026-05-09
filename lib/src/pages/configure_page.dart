import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../device/device_configure_page.dart';
import '../demo_configuration.dart';
import '../demo_permissions.dart';
import '../demo_test_hooks.dart';
import '../settings/demo_example_settings_store.dart';
import '../widgets/configure_page_widgets.dart';
import 'player_page.dart';
import 'qr_scanner_page.dart';
import 'settings_page.dart';

class DemoConfigurePage extends StatefulWidget {
  const DemoConfigurePage({super.key});

  @override
  State<DemoConfigurePage> createState() => _DemoConfigurePageState();
}

class _DemoConfigurePageState extends State<DemoConfigurePage> with WidgetsBindingObserver {
  static const SystemUiOverlayStyle _configurePageOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _appIdController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _remoteIdController = TextEditingController();
  final TextEditingController _audioStreamIdController = TextEditingController();
  final TextEditingController _videoStreamIdController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final DemoExamplePermissions _permissions = const DemoExamplePermissions();
  final DemoExampleSettingsStore _settingsStore = const DemoExampleSettingsStore();

  bool _submitted = false;
  bool _startingPlayer = false;
  DemoExampleSettings _settings = const DemoExampleSettings();
  bool _iosLocalNetworkPermissionRequested = false;

  bool get _scanSupported => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadSettingsSnapshot(reason: 'initial'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyConfigurePageSystemOverlayStyle();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appIdController.dispose();
    _endpointController.dispose();
    _remoteIdController.dispose();
    _audioStreamIdController.dispose();
    _videoStreamIdController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showBackdropOrbs = !Platform.isMacOS;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _configurePageOverlayStyle,
      child: Scaffold(
        body: ConfigurePageBackground(
          showBackdropOrbs: showBackdropOrbs,
          onTap: _dismissKeyboard,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ConfigureHeader(
                        scanSupported: _scanSupported,
                        startingPlayer: _startingPlayer,
                        onOpenSettings: _openSettings,
                        onScanToken: _scanToken,
                      ),
                      const SizedBox(height: 20),
                      ConfigureForm(
                        formKey: _formKey,
                        submitted: _submitted,
                        startingPlayer: _startingPlayer,
                        appIdController: _appIdController,
                        endpointController: _endpointController,
                        remoteIdController: _remoteIdController,
                        audioStreamIdController: _audioStreamIdController,
                        videoStreamIdController: _videoStreamIdController,
                        tokenController: _tokenController,
                        validateEndpoint: _validateEndpoint,
                        validateStreamId: _validateStreamId,
                        onStartPlaying: _startPlaying,
                      ),
                      const SizedBox(height: 14),
                      ConfigureDeviceEntryLink(
                        startingPlayer: _startingPlayer,
                        onOpenDeviceServer: _openDeviceServer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEndpoint(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return '请输入完整的 http(s) URL。';
    }
    return null;
  }

  String? _validateStreamId(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    if (int.tryParse(text) == null) {
      return '请输入整数。';
    }
    return null;
  }

  String _resolvedEndpoint() {
    return _endpointController.text.trim();
  }

  String _resolvedAppId() {
    return _appIdController.text.trim();
  }

  Future<void> _scanToken() async {
    _dismissKeyboard();
    final DemoScanPayload? payload = await Navigator.of(context).push<DemoScanPayload>(
      MaterialPageRoute<DemoScanPayload>(
        builder: (BuildContext context) => const DemoQrScannerPage(),
      ),
    );
    _dismissKeyboard();
    _applyConfigurePageSystemOverlayStyle();
    if (!mounted || payload == null) {
      return;
    }

    _appIdController.text = payload.appId;
    _remoteIdController.text = payload.remoteId;
    _tokenController.text = payload.token;
    _applyScannedEndpoint(payload.endpoint);
    TiRtcLogging.i(
      'flutter_example',
      'scan_payload_applied appIdPresent=${payload.appId.isNotEmpty} '
          'remoteId=${payload.remoteId} endpoint=${_resolvedEndpoint()}',
    );

    _showSnack(
      payload.endpoint == null || payload.endpoint!.trim().isEmpty
          ? '扫码成功，已填充 app_id / remote_id / token，并保留当前 endpoint。'
          : '扫码成功，已填充 app_id / remote_id / token / endpoint。',
    );
  }

  void _applyScannedEndpoint(String? endpoint) {
    final String normalizedEndpoint = (endpoint ?? '').trim();
    if (normalizedEndpoint.isEmpty) {
      return;
    }
    _endpointController.value = TextEditingValue(
      text: normalizedEndpoint,
      selection: TextSelection.collapsed(offset: normalizedEndpoint.length),
    );
    _appIdController.selection = TextSelection.collapsed(offset: _appIdController.text.length);
    _remoteIdController.selection = TextSelection.collapsed(offset: _remoteIdController.text.length);
    _tokenController.selection = TextSelection.collapsed(offset: _tokenController.text.length);
  }

  Future<void> _startPlaying() async {
    final DemoDownlinkConfiguration? configuration = _validatedConfiguration(showFeedback: true);
    if (configuration == null) {
      return;
    }
    await _openPlayer(configuration);
  }

  DemoDownlinkConfiguration? _validatedConfiguration({
    required bool showFeedback,
  }) {
    setState(() {
      _submitted = true;
    });

    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      if (showFeedback) {
        _showSnack('请先补全必填项。');
      }
      return null;
    }

    return DemoDownlinkConfiguration(
      appId: _resolvedAppId(),
      endpoint: _resolvedEndpoint(),
      remoteId: _remoteIdController.text.trim(),
      audioStreamId: _resolvedStreamId(
        controller: _audioStreamIdController,
        fallback: DemoDownlinkConfiguration.defaultAudioStreamId,
      ),
      videoStreamId: _resolvedStreamId(
        controller: _videoStreamIdController,
        fallback: DemoDownlinkConfiguration.defaultVideoStreamId,
      ),
      token: _tokenController.text.trim(),
      settings: _settings,
    );
  }

  int _resolvedStreamId({
    required TextEditingController controller,
    required int fallback,
  }) {
    final String text = controller.text.trim();
    if (text.isEmpty) {
      return fallback;
    }
    return int.parse(text);
  }

  Future<void> _openPlayer(DemoDownlinkConfiguration configuration) async {
    if (_startingPlayer) {
      return;
    }

    _dismissKeyboard();
    setState(() {
      _startingPlayer = true;
    });

    await _requestIosLocalNetworkPermissionIfNeeded();

    TiRtcLogging.i(
      'flutter_example',
      'runtime_initialize_requested appIdPresent=${configuration.appId.isNotEmpty} '
          'endpoint=${configuration.endpoint} remoteId=${configuration.remoteId}',
    );
    final int initializeCode = await TiRtc.initialize(
      TiRtcInitOptions(
        appId: configuration.appId,
        endpoint: configuration.endpoint,
        consoleLogEnabled: configuration.settings.consoleLogEnabled,
      ),
    );
    if (!mounted) {
      if (initializeCode == 0) {
        _shutdownRuntime();
      }
      return;
    }

    if (initializeCode != 0) {
      setState(() {
        _startingPlayer = false;
      });
      TiRtcLogging.w(
        'flutter_example',
        'runtime_initialize_failed code=$initializeCode endpoint=${configuration.endpoint}',
      );
      _showSnack('运行时初始化失败，code $initializeCode。');
      return;
    }

    TiRtcLogging.i(
      'flutter_example',
      'runtime_initialized endpoint=${configuration.endpoint}',
    );

    try {
      TiRtcLogging.i(
        'flutter_example',
        'open_player endpoint=${configuration.endpoint} '
            'remoteId=${configuration.remoteId} '
            'audioStreamId=${configuration.audioStreamId} '
            'videoStreamId=${configuration.videoStreamId}',
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            final DemoExampleSmokeHooks? smokeHooks = DemoExampleSmokeHooks.current;
            return DemoPlayerPage(
              configuration: configuration,
              smokeMarkerSink: smokeHooks?.markerSink,
              smokeRenderWindowSeconds: smokeHooks?.renderWindowSeconds ?? 30,
            );
          },
        ),
      );
      _dismissKeyboard();
      _applyConfigurePageSystemOverlayStyle();
      _clearTokenAfterDownlinkReturn();
    } finally {
      final int shutdownCode = _shutdownRuntime();
      if (shutdownCode != 0) {
        TiRtcLogging.w('flutter_example', 'runtime_shutdown_failed code=$shutdownCode');
      }
      if (mounted) {
        setState(() {
          _startingPlayer = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    _dismissKeyboard();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DemoSettingsPage(
          initialSettings: _settings,
          settingsStore: _settingsStore,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadSettingsSnapshot(reason: 'settings_return');
    _applyConfigurePageSystemOverlayStyle();
  }

  Future<void> _openDeviceServer() async {
    _dismissKeyboard();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const DemoDeviceServerConfigurePage(),
      ),
    );
    if (!mounted) {
      return;
    }
    _applyConfigurePageSystemOverlayStyle();
  }

  Future<void> _loadSettingsSnapshot({required String reason}) async {
    final DemoExampleSettings settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
    TiRtcLogging.i(
      'flutter_example',
      'example_settings_loaded reason=$reason '
          'video_decoder_preference=${settings.videoDecoderPreference} '
          'console_log_enabled=${settings.consoleLogEnabled}',
    );
  }

  Future<void> _requestIosLocalNetworkPermissionIfNeeded() async {
    if (!Platform.isIOS || _iosLocalNetworkPermissionRequested) {
      return;
    }

    _iosLocalNetworkPermissionRequested = true;
    TiRtcLogging.i('flutter_example', 'ios_local_network_permission_request_started');
    await _permissions.requestLocalNetworkPermissionIfNeeded();
    TiRtcLogging.i('flutter_example', 'ios_local_network_permission_request_finished');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyConfigurePageSystemOverlayStyle();
    }
  }

  void _applyConfigurePageSystemOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(_configurePageOverlayStyle);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _clearTokenAfterDownlinkReturn() {
    _tokenController.clear();
    _showSnack('已返回配置页，token 已清空，请重新扫码或粘贴。');
  }

  int _shutdownRuntime() {
    TiRtcLogging.i('flutter_example', 'runtime_shutdown_requested');
    return TiRtc.shutdown();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
