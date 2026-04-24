import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';
import 'player_page.dart';
import 'qr_scanner_page.dart';

class DemoConfigurePage extends StatefulWidget {
  const DemoConfigurePage({super.key});

  @override
  State<DemoConfigurePage> createState() => _DemoConfigurePageState();
}

class _DemoConfigurePageState extends State<DemoConfigurePage> with WidgetsBindingObserver {
  static const MethodChannel _permissionChannel = MethodChannel(
    'tirtc_av_kit_example/permissions',
  );
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

  bool _submitted = false;
  bool _startingPlayer = false;
  bool _iosLocalNetworkPermissionRequested = false;
  bool _iosLocalNetworkPermissionScheduled = false;

  bool get _scanSupported => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyConfigurePageSystemOverlayStyle();
      _scheduleIosLocalNetworkPermissionRequestIfNeeded();
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
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKeyboard,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: ExampleTheme.pageBackgroundDecoration,
                ),
              ),
              if (showBackdropOrbs)
                const Positioned(
                  top: -120,
                  right: -90,
                  child: _DecorativeOrb(size: 260, color: ExampleTheme.overlayGlow),
                ),
              if (showBackdropOrbs)
                const Positioned(
                  bottom: -110,
                  left: -70,
                  child: _DecorativeOrb(size: 220, color: ExampleTheme.overlayShadow),
                ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildHeader(context),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: ExampleTheme.surface.withAlpha(224),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Form(
                              key: _formKey,
                              autovalidateMode: _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  _buildAppIdField(),
                                  const SizedBox(height: 16),
                                  _buildEndpointField(),
                                  const SizedBox(height: 16),
                                  _buildRemoteIdField(),
                                  const SizedBox(height: 16),
                                  _buildStreamIdRow(),
                                  const SizedBox(height: 16),
                                  _buildTokenField(),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: _startingPlayer ? null : _startPlaying,
                                    child: _buildEnterPlayerButtonLabel(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final TextStyle baseStyle = Theme.of(context).textTheme.headlineLarge ?? const TextStyle();
    final TextStyle titleStyle = baseStyle.copyWith(
      fontSize: 22,
      color: ExampleTheme.brandText,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.0,
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Ti RTC',
            style: titleStyle,
          ),
        ),
        if (_scanSupported)
          TextButton.icon(
            onPressed: _startingPlayer ? null : _scanToken,
            style: TextButton.styleFrom(
              foregroundColor: _startingPlayer ? ExampleTheme.textHint : ExampleTheme.primary,
              backgroundColor: ExampleTheme.surface.withAlpha(214),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: (_startingPlayer ? ExampleTheme.textHint : ExampleTheme.primary).withAlpha(64),
                ),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text(
              '扫一扫',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildEnterPlayerButtonLabel() {
    if (!_startingPlayer) {
      return const Text('进入播放页');
    }

    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(ExampleTheme.foreground),
          ),
        ),
        SizedBox(width: 10),
        Text('初始化中'),
      ],
    );
  }

  Widget _buildEndpointField() {
    return TextFormField(
      controller: _endpointController,
      enabled: !_startingPlayer,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        labelText: 'endpoint',
        hintText: '接入的云端环境，留空则使用默认环境。',
      ),
      validator: _validateEndpoint,
    );
  }

  Widget _buildAppIdField() {
    return TextFormField(
      controller: _appIdController,
      enabled: !_startingPlayer,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        labelText: 'app_id',
        hintText: 'TiRTC 应用标识，进入播放页前必须提供。',
      ),
      validator: (String? value) {
        if ((value ?? '').trim().isEmpty) {
          return 'app_id 为必填项。';
        }
        return null;
      },
    );
  }

  Widget _buildRemoteIdField() {
    return TextFormField(
      controller: _remoteIdController,
      enabled: !_startingPlayer,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        labelText: 'remote_id',
        hintText: '待连接的远端目标 ID',
      ),
      validator: (String? value) {
        if ((value ?? '').trim().isEmpty) {
          return 'remote_id 为必填项。';
        }
        return null;
      },
    );
  }

  Widget _buildStreamIdRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextFormField(
            controller: _audioStreamIdController,
            enabled: !_startingPlayer,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'audio_stream_id',
              hintText: '音频流 ID，默认 10',
            ),
            validator: _validateStreamId,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _videoStreamIdController,
            enabled: !_startingPlayer,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'video_stream_id',
              hintText: '视频流 ID，默认 11',
            ),
            validator: _validateStreamId,
          ),
        ),
      ],
    );
  }

  Widget _buildTokenField() {
    return TextFormField(
      controller: _tokenController,
      enabled: !_startingPlayer,
      minLines: 3,
      maxLines: 5,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        labelText: 'token',
        hintText: '进行一次连接所需的有效 token',
        alignLabelWithHint: true,
      ),
      validator: (String? value) {
        if ((value ?? '').trim().isEmpty) {
          return 'token 为必填项。';
        }
        return null;
      },
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
    final DemoPlaybackConfiguration? configuration = _validatedConfiguration(showFeedback: true);
    if (configuration == null) {
      return;
    }
    await _openPlayer(configuration);
  }

  DemoPlaybackConfiguration? _validatedConfiguration({
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

    return DemoPlaybackConfiguration(
      appId: _resolvedAppId(),
      endpoint: _resolvedEndpoint(),
      remoteId: _remoteIdController.text.trim(),
      audioStreamId: _resolvedStreamId(
        controller: _audioStreamIdController,
        fallback: DemoPlaybackConfiguration.defaultAudioStreamId,
      ),
      videoStreamId: _resolvedStreamId(
        controller: _videoStreamIdController,
        fallback: DemoPlaybackConfiguration.defaultVideoStreamId,
      ),
      token: _tokenController.text.trim(),
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

  Future<void> _openPlayer(DemoPlaybackConfiguration configuration) async {
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
        consoleLogEnabled: true,
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
          builder: (BuildContext context) => DemoPlayerPage(configuration: configuration),
        ),
      );
      _dismissKeyboard();
      _applyConfigurePageSystemOverlayStyle();
      _clearTokenAfterPlaybackReturn();
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

  Future<void> _requestIosLocalNetworkPermissionIfNeeded() async {
    if (!Platform.isIOS || _iosLocalNetworkPermissionRequested) {
      return;
    }

    _iosLocalNetworkPermissionRequested = true;
    TiRtcLogging.i('flutter_example', 'ios_local_network_permission_request_started');
    try {
      await _permissionChannel.invokeMethod<bool>('requestLocalNetworkPermission');
      TiRtcLogging.i('flutter_example', 'ios_local_network_permission_request_finished');
    } on PlatformException catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        'ios_local_network_permission_request_failed '
            'code=${error.code} message=${error.message ?? ''}',
      );
    }
  }

  void _scheduleIosLocalNetworkPermissionRequestIfNeeded() {
    if (!Platform.isIOS || _iosLocalNetworkPermissionRequested || _iosLocalNetworkPermissionScheduled || !mounted) {
      return;
    }

    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    _iosLocalNetworkPermissionScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 600), () async {
      _iosLocalNetworkPermissionScheduled = false;
      if (!mounted) {
        return;
      }
      await _requestIosLocalNetworkPermissionIfNeeded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleIosLocalNetworkPermissionRequestIfNeeded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyConfigurePageSystemOverlayStyle();
      _scheduleIosLocalNetworkPermissionRequestIfNeeded();
    }
  }

  void _applyConfigurePageSystemOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(_configurePageOverlayStyle);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _clearTokenAfterPlaybackReturn() {
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

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withAlpha(0)],
          ),
        ),
      ),
    );
  }
}
