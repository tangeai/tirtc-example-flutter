import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../demo_widget_keys.dart';

class ConfigurePageBackground extends StatelessWidget {
  const ConfigurePageBackground({
    super.key,
    required this.showBackdropOrbs,
    required this.onTap,
    required this.child,
  });

  final bool showBackdropOrbs;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
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
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class ConfigureHeader extends StatelessWidget {
  const ConfigureHeader({
    super.key,
    required this.scanSupported,
    required this.startingPlayer,
    required this.onOpenSettings,
    required this.onScanToken,
  });

  final bool scanSupported;
  final bool startingPlayer;
  final VoidCallback onOpenSettings;
  final VoidCallback onScanToken;

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
        Expanded(
          child: Text(
            'Ti RTC',
            style: titleStyle,
          ),
        ),
        IconButton(
          tooltip: '设置',
          onPressed: startingPlayer ? null : onOpenSettings,
          style: IconButton.styleFrom(
            foregroundColor: startingPlayer ? ExampleTheme.textHint : ExampleTheme.primary,
            backgroundColor: ExampleTheme.surface.withAlpha(214),
            minimumSize: const Size.square(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: (startingPlayer ? ExampleTheme.textHint : ExampleTheme.primary).withAlpha(64),
              ),
            ),
          ),
          icon: const Icon(Icons.settings_rounded, size: 18),
        ),
        const SizedBox(width: 8),
        if (scanSupported)
          TextButton.icon(
            onPressed: startingPlayer ? null : onScanToken,
            style: TextButton.styleFrom(
              foregroundColor: startingPlayer ? ExampleTheme.textHint : ExampleTheme.primary,
              backgroundColor: ExampleTheme.surface.withAlpha(214),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: (startingPlayer ? ExampleTheme.textHint : ExampleTheme.primary).withAlpha(64),
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
}

class ConfigureDeviceEntryLink extends StatelessWidget {
  const ConfigureDeviceEntryLink({
    super.key,
    required this.startingPlayer,
    required this.onOpenDeviceServer,
  });

  final bool startingPlayer;
  final VoidCallback onOpenDeviceServer;

  @override
  Widget build(BuildContext context) {
    final Color textColor = startingPlayer ? ExampleTheme.textHint : ExampleTheme.textSecondary;
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        key: DemoWidgetKeys.openDeviceServerButton,
        onPressed: startingPlayer ? null : onOpenDeviceServer,
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          '作为设备端启动',
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: textColor,
          ),
        ),
      ),
    );
  }
}

class ConfigureForm extends StatelessWidget {
  const ConfigureForm({
    super.key,
    required this.formKey,
    required this.submitted,
    required this.startingPlayer,
    required this.appIdController,
    required this.endpointController,
    required this.remoteIdController,
    required this.audioStreamIdController,
    required this.videoStreamIdController,
    required this.tokenController,
    required this.validateEndpoint,
    required this.validateStreamId,
    required this.onStartPlaying,
  });

  final GlobalKey<FormState> formKey;
  final bool submitted;
  final bool startingPlayer;
  final TextEditingController appIdController;
  final TextEditingController endpointController;
  final TextEditingController remoteIdController;
  final TextEditingController audioStreamIdController;
  final TextEditingController videoStreamIdController;
  final TextEditingController tokenController;
  final FormFieldValidator<String> validateEndpoint;
  final FormFieldValidator<String> validateStreamId;
  final VoidCallback onStartPlaying;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ExampleTheme.surface.withAlpha(224),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Form(
        key: formKey,
        autovalidateMode: submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _AppIdField(controller: appIdController, enabled: !startingPlayer),
            const SizedBox(height: 16),
            _EndpointField(
              controller: endpointController,
              enabled: !startingPlayer,
              validator: validateEndpoint,
            ),
            const SizedBox(height: 16),
            _RemoteIdField(controller: remoteIdController, enabled: !startingPlayer),
            const SizedBox(height: 16),
            _StreamIdRow(
              audioStreamIdController: audioStreamIdController,
              videoStreamIdController: videoStreamIdController,
              enabled: !startingPlayer,
              validator: validateStreamId,
            ),
            const SizedBox(height: 16),
            _TokenField(controller: tokenController, enabled: !startingPlayer),
            const SizedBox(height: 20),
            FilledButton(
              key: DemoWidgetKeys.startDownlinkButton,
              onPressed: startingPlayer ? null : onStartPlaying,
              child: _EnterPlayerButtonLabel(startingPlayer: startingPlayer),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointField extends StatelessWidget {
  const _EndpointField({
    required this.controller,
    required this.enabled,
    required this.validator,
  });

  final TextEditingController controller;
  final bool enabled;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: DemoWidgetKeys.endpointField,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        labelText: 'endpoint',
        hintText: '接入的云端环境，留空则使用默认环境。',
      ),
      validator: validator,
    );
  }
}

class _AppIdField extends StatelessWidget {
  const _AppIdField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: DemoWidgetKeys.appIdField,
      controller: controller,
      enabled: enabled,
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
}

class _RemoteIdField extends StatelessWidget {
  const _RemoteIdField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: DemoWidgetKeys.remoteIdField,
      controller: controller,
      enabled: enabled,
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
}

class _StreamIdRow extends StatelessWidget {
  const _StreamIdRow({
    required this.audioStreamIdController,
    required this.videoStreamIdController,
    required this.enabled,
    required this.validator,
  });

  final TextEditingController audioStreamIdController;
  final TextEditingController videoStreamIdController;
  final bool enabled;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextFormField(
            key: DemoWidgetKeys.audioStreamIdField,
            controller: audioStreamIdController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'audio_stream_id',
              hintText: '音频流 ID，默认 10',
            ),
            validator: validator,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            key: DemoWidgetKeys.videoStreamIdField,
            controller: videoStreamIdController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'video_stream_id',
              hintText: '视频流 ID，默认 11',
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}

class _TokenField extends StatelessWidget {
  const _TokenField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: DemoWidgetKeys.tokenField,
      controller: controller,
      enabled: enabled,
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
}

class _EnterPlayerButtonLabel extends StatelessWidget {
  const _EnterPlayerButtonLabel({required this.startingPlayer});

  final bool startingPlayer;

  @override
  Widget build(BuildContext context) {
    if (!startingPlayer) {
      return const Text('进入播放页面');
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
