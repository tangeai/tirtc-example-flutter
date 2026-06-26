import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';
import '../demo_permissions.dart';
import '../demo_test_hooks.dart';
import '../demo_widget_keys.dart';
import '../settings/demo_example_settings_store.dart';
import '../settings/device_server_configuration_store.dart';
import '../widgets/configure_page_widgets.dart';
import '../widgets/notice_dialog.dart';
import 'device_page.dart';

class DemoDeviceServerConfigurePage extends StatefulWidget {
  const DemoDeviceServerConfigurePage({super.key});

  @override
  State<DemoDeviceServerConfigurePage> createState() => _DemoDeviceServerConfigurePageState();
}

class _DemoDeviceServerConfigurePageState extends State<DemoDeviceServerConfigurePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _deviceSecretKeyController = TextEditingController();
  final DemoExamplePermissions _permissions = const DemoExamplePermissions();
  final DemoExampleSettingsStore _settingsStore = const DemoExampleSettingsStore();
  final DemoDeviceServerConfigurationStore _configurationStore = const DemoDeviceServerConfigurationStore();

  DemoExampleSettings _settings = const DemoExampleSettings();
  DemoDeviceCameraFacing _cameraFacing = DemoDeviceCameraFacing.back;
  DemoDeviceVideoCodec _videoCodec = DemoDeviceVideoCodec.h264;
  DemoDeviceEncoderPreference _encoderPreference = DemoDeviceEncoderPreference.hardware;
  bool _submitted = false;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPersistedConfiguration());
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _deviceIdController.dispose();
    _deviceSecretKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ConfigurePageBackground(
        showBackdropOrbs: !Platform.isMacOS,
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
                    _DeviceServerHeader(
                      saving: _saving,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 20),
                    _buildForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            key: DemoWidgetKeys.deviceEndpointField,
            controller: _endpointController,
            enabled: !_saving,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'endpoint',
              hintText: '接入的云端环境，留空则使用默认环境。',
            ),
            validator: _validateEndpoint,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: DemoWidgetKeys.deviceIdField,
            controller: _deviceIdController,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'device_id',
              hintText: '设备端身份标识。',
            ),
            validator: _required('device_id'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: DemoWidgetKeys.deviceSecretKeyField,
            controller: _deviceSecretKeyController,
            enabled: !_saving,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'device_secret_key',
              hintText: '设备端连接密钥。',
              alignLabelWithHint: true,
            ),
            validator: _required('device_secret_key'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: DemoWidgetKeys.startDeviceServerButton,
            onPressed: _saving || !_loaded ? null : _submit,
            child: _saving ? const Text('保存中') : const Text('进入设备端'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPersistedConfiguration() async {
    final DemoExampleSettings settings = await _settingsStore.load();
    final DemoDeviceServerConfigurationSnapshot snapshot = await _configurationStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _endpointController.text = snapshot.endpoint;
      _deviceIdController.text = snapshot.deviceId;
      _deviceSecretKeyController.text = snapshot.deviceSecretKey;
      _cameraFacing = snapshot.cameraFacing;
      _videoCodec = snapshot.videoCodec;
      _encoderPreference = snapshot.encoderPreference;
      _loaded = true;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnack('请先补全必填项。');
      return;
    }
    final DemoDeviceServerConfiguration configuration = DemoDeviceServerConfiguration(
      endpoint: _endpointController.text.trim(),
      deviceId: _deviceIdController.text.trim(),
      deviceSecretKey: _deviceSecretKeyController.text.trim(),
      cameraFacing: _cameraFacing,
      videoCodec: _videoCodec,
      encoderPreference: _encoderPreference,
      settings: _settings,
    );
    if (!configuration.validCodecBackend) {
      _showSnack('MJPEG 仅支持软编。');
      return;
    }

    setState(() {
      _saving = true;
    });

    final bool capturePermissionsReady = await _ensureCapturePermissions();
    if (!mounted) {
      return;
    }
    if (!capturePermissionsReady) {
      setState(() {
        _saving = false;
      });
      unawaited(
        _showDeviceServerFailureDialog(
          stage: 'capture_permission',
          message: '需要允许摄像头和麦克风权限后，才能进入设备端播放页面。',
          endpoint: configuration.endpoint,
        ),
      );
      return;
    }

    try {
      await _configurationStore.save(configuration);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      _showSnack('保存设备端配置失败：$error');
      return;
    }
    if (!mounted) {
      return;
    }
    final int initializeCode = await TiRtc.initialize(
      TiRtcInitOptions(
        appId: '',
        endpoint: configuration.endpoint,
        consoleLogEnabled: configuration.settings.consoleLogEnabled,
      ),
    );
    if (!mounted) {
      if (initializeCode == 0) {
        TiRtc.shutdown();
      }
      return;
    }
    if (initializeCode != 0) {
      setState(() {
        _saving = false;
      });
      unawaited(
        _showDeviceServerFailureDialog(
          stage: 'runtime_init',
          message: '运行时初始化失败。',
          endpoint: configuration.endpoint,
          errorCode: initializeCode,
        ),
      );
      return;
    }
    try {
      setState(() {
        _saving = false;
      });
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            final DemoExampleSmokeHooks? smokeHooks = DemoExampleSmokeHooks.current;
            return DemoDeviceServerPage(
              configuration: configuration,
              runtimeAlreadyInitialized: true,
              smokeMarkerSink: smokeHooks?.markerSink,
              smokeRenderWindowSeconds: smokeHooks?.renderWindowSeconds,
            );
          },
        ),
      );
    } catch (_) {
      TiRtc.shutdown();
      rethrow;
    }
  }

  Future<bool> _ensureCapturePermissions() async {
    TiRtcLogging.i('flutter_example', 'camera_permission_check_started');
    final bool cameraGranted = await _permissions.checkCameraPermission() || await _requestCameraPermission();
    TiRtcLogging.i('flutter_example', 'camera_permission_ready granted=$cameraGranted');
    if (!cameraGranted) {
      return false;
    }

    TiRtcLogging.i('flutter_example', 'microphone_permission_check_started');
    final bool microphoneGranted =
        await _permissions.checkMicrophonePermission() || await _requestMicrophonePermission();
    TiRtcLogging.i('flutter_example', 'microphone_permission_ready granted=$microphoneGranted');
    if (!microphoneGranted) {
      return false;
    }
    return true;
  }

  Future<bool> _requestCameraPermission() async {
    TiRtcLogging.i('flutter_example', 'camera_permission_request_started');
    final bool granted = await _permissions.requestCameraPermission();
    TiRtcLogging.i('flutter_example', 'camera_permission_request_finished granted=$granted');
    return granted;
  }

  Future<bool> _requestMicrophonePermission() async {
    TiRtcLogging.i('flutter_example', 'microphone_permission_request_started');
    final bool granted = await _permissions.requestMicrophonePermission();
    TiRtcLogging.i('flutter_example', 'microphone_permission_request_finished granted=$granted');
    return granted;
  }

  String? _validateEndpoint(String? value) {
    final String text = (value ?? '').trim();
    if (!demoEndpointValid(text)) {
      return '请输入完整的 http(s) URL。';
    }
    return null;
  }

  FormFieldValidator<String> _required(String label) {
    return (String? value) {
      if ((value ?? '').trim().isEmpty) {
        return '$label 为必填项。';
      }
      return null;
    };
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showDeviceServerFailureDialog({
    required String stage,
    required String message,
    required String endpoint,
    int? errorCode,
    String? nativeMessage,
  }) {
    return context.showNoticeDialog(
      title: '设备端启动失败',
      content: _deviceServerFailureDialogContent(
        stage: stage,
        message: message,
        endpoint: endpoint,
        errorCode: errorCode,
        nativeMessage: nativeMessage,
      ),
    );
  }

  String _deviceServerFailureDialogContent({
    required String stage,
    required String message,
    required String endpoint,
    int? errorCode,
    String? nativeMessage,
  }) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(message)
      ..writeln()
      ..writeln('阶段：$stage');
    if (errorCode != null) {
      buffer.writeln('错误码：${TiRtc.formatError(errorCode)}');
    }
    final String normalizedNativeMessage = (nativeMessage ?? '').trim();
    if (normalizedNativeMessage.isNotEmpty) {
      buffer.writeln('底层信息：$normalizedNativeMessage');
    }
    final String normalizedEndpoint = endpoint.trim();
    if (normalizedEndpoint.isNotEmpty) {
      buffer.writeln('endpoint：$normalizedEndpoint');
    }
    return buffer.toString().trimRight();
  }
}

class _DeviceServerHeader extends StatelessWidget {
  const _DeviceServerHeader({
    required this.saving,
    required this.onBack,
  });

  final bool saving;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle = Theme.of(context).textTheme.headlineLarge ?? const TextStyle();
    final TextStyle titleStyle = baseStyle.copyWith(
      fontSize: 22,
      color: ExampleTheme.brandText,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      height: 1.0,
    );

    return Row(
      children: <Widget>[
        IconButton(
          tooltip: '返回',
          onPressed: saving ? null : onBack,
          style: IconButton.styleFrom(
            foregroundColor: saving ? ExampleTheme.textHint : ExampleTheme.primary,
            backgroundColor: ExampleTheme.surface,
            minimumSize: const Size.square(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '设备端',
            style: titleStyle,
          ),
        ),
      ],
    );
  }
}
