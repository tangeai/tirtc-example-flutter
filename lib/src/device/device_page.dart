import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';
import '../demo_device_server_controller.dart';
import '../demo_downlink_support.dart';
import '../demo_test_hooks.dart';
import '../demo_widget_keys.dart';
import '../widgets/downlink_center_loading.dart';
import '../widgets/notice_dialog.dart';
import '../widgets/player_page_widgets.dart';

class DemoDeviceServerPage extends StatefulWidget {
  const DemoDeviceServerPage({
    super.key,
    required this.configuration,
    this.runtimeAlreadyInitialized = false,
    this.smokeMarkerSink,
    this.smokeRenderWindowSeconds,
  });

  final DemoDeviceServerConfiguration configuration;
  final bool runtimeAlreadyInitialized;
  final DemoAutomationMarkerSink? smokeMarkerSink;
  final int? smokeRenderWindowSeconds;

  @override
  State<DemoDeviceServerPage> createState() => _DemoDeviceServerPageState();
}

class _DemoDeviceServerPageState extends State<DemoDeviceServerPage> {
  final DemoLogUploader _logUploader = DemoLogUploader();
  late final DemoDeviceServerController _controller;
  bool _failureDialogShown = false;
  bool _uploadingLogs = false;

  @override
  void initState() {
    super.initState();
    _controller = DemoDeviceServerController(
      configuration: widget.configuration,
      markerSink: widget.smokeMarkerSink,
      renderWindowSeconds: widget.smokeRenderWindowSeconds,
      runtimeAlreadyInitialized: widget.runtimeAlreadyInitialized,
    )..addListener(_handleControllerChanged);
    unawaited(_startController());
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    unawaited(_controller.release(reason: 'manual_page_dispose').whenComplete(_controller.shutdownRuntime));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String stageLabel = _controller.failed ? '启动失败' : _controller.stageLabel;
    return Scaffold(
      key: DemoWidgetKeys.deviceServerPage,
      backgroundColor: ExampleTheme.background,
      appBar: AppBar(
        title: Text(
          widget.configuration.deviceId,
          style: const TextStyle(
            color: ExampleTheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: <Widget>[
          PlayerLogUploadButton(
            uploadingLogs: _uploadingLogs,
            onUploadLogs: _uploadLogs,
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DownlinkVideoStage(
              videoView: _controller.buildLocalPreview(),
              showStageOverlay: !_controller.localPreviewVisible || _controller.failed,
              stageStatusLabel: _controller.failureMessage ?? stageLabel,
              indicatorMode:
                  _controller.failed ? DownlinkCenterIndicatorMode.error : DownlinkCenterIndicatorMode.loading,
            ),
          ),
          const Positioned.fill(child: DownlinkOverlayGradient()),
        ],
      ),
    );
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
      _showFailureDialogIfNeeded();
    }
  }

  Future<void> _startController() async {
    final int code = await _controller.start();
    if (!mounted || code == 0) {
      return;
    }
    _showFailureDialogIfNeeded();
  }

  Future<void> _uploadLogs() async {
    if (_uploadingLogs) {
      return;
    }

    setState(() {
      _uploadingLogs = true;
    });

    try {
      await _logUploader.upload(
        remoteId: widget.configuration.deviceId,
        isActive: () => mounted,
        showResult: _showLogUploadResultIfMounted,
      );
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
    return context.showNoticeDialog(
      title: title,
      content: content,
    );
  }

  void _showFailureDialogIfNeeded() {
    if (!mounted || !_controller.failed || _failureDialogShown) {
      return;
    }
    _failureDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await context.showNoticeDialog(
        title: '设备端启动失败',
        content: _failureDialogContent(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  String _failureDialogContent() {
    final StringBuffer buffer = StringBuffer()
      ..writeln(_controller.failureMessage ?? '设备端启动失败。')
      ..writeln()
      ..writeln('阶段：${_controller.failureStage ?? 'unknown'}');
    final int? errorCode = _controller.failureErrorCode;
    if (errorCode != null) {
      buffer.writeln('错误码：${TiRtc.formatError(errorCode)}');
    }
    final String normalizedNativeMessage = (_controller.failureNativeMessage ?? '').trim();
    if (normalizedNativeMessage.isNotEmpty) {
      buffer.writeln('底层信息：$normalizedNativeMessage');
    }
    final String normalizedEndpoint = widget.configuration.endpoint.trim();
    if (normalizedEndpoint.isNotEmpty) {
      buffer.writeln('endpoint：$normalizedEndpoint');
    }
    return buffer.toString().trimRight();
  }
}
