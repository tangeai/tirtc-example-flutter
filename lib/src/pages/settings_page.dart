import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';
import '../settings/demo_example_settings_store.dart';

class DemoSettingsPage extends StatefulWidget {
  const DemoSettingsPage({
    super.key,
    required this.initialSettings,
    this.settingsStore = const DemoExampleSettingsStore(),
  });

  final DemoExampleSettings initialSettings;
  final DemoExampleSettingsStore settingsStore;

  @override
  State<DemoSettingsPage> createState() => _DemoSettingsPageState();
}

class _DemoSettingsPageState extends State<DemoSettingsPage> {
  late DemoExampleSettings _settings = widget.initialSettings;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: DecoratedBox(
        decoration: ExampleTheme.pageBackgroundDecoration,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: <Widget>[
              const _SettingsSectionTitle(label: '视频'),
              _SettingsSurface(
                child: ListTile(
                  enabled: !_saving,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('视频解码偏好'),
                  subtitle: Text(
                    DemoExampleSettings.videoDecoderPreferenceLabel(_settings.videoDecoderPreference),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: ExampleTheme.textSecondary,
                  ),
                  onTap: _saving
                      ? null
                      : () {
                          unawaited(_chooseVideoDecoderPreference());
                        },
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsSectionTitle(label: '调试'),
              _SettingsSurface(
                child: SwitchListTile(
                  value: _settings.consoleLogEnabled,
                  onChanged: _saving
                      ? null
                      : (bool value) {
                          unawaited(_setConsoleLogEnabled(value));
                        },
                  activeThumbColor: ExampleTheme.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('启用控制台输出'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setVideoDecoderPreference(int? value) async {
    if (value == null || !DemoExampleSettings.isValidVideoDecoderPreference(value)) {
      return;
    }
    if (value == _settings.videoDecoderPreference) {
      return;
    }
    await _saveSettings(
      _settings.copyWith(videoDecoderPreference: value),
      reason: 'video_decoder_preference',
    );
  }

  Future<void> _chooseVideoDecoderPreference() async {
    final int? value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: ExampleTheme.background,
      builder: (BuildContext context) {
        return _DecoderPreferenceSheet(
          currentPreference: _settings.videoDecoderPreference,
        );
      },
    );
    if (!mounted || value == null) {
      return;
    }
    await _setVideoDecoderPreference(value);
  }

  Future<void> _setConsoleLogEnabled(bool value) async {
    await _saveSettings(
      _settings.copyWith(consoleLogEnabled: value),
      reason: 'console_log_enabled',
    );
  }

  Future<void> _saveSettings(
    DemoExampleSettings nextSettings, {
    required String reason,
  }) async {
    final DemoExampleSettings previousSettings = _settings;
    setState(() {
      _settings = nextSettings;
      _saving = true;
    });

    try {
      await widget.settingsStore.save(nextSettings);
      TiRtcLogging.i(
        'flutter_example',
        'example_settings_saved reason=$reason '
            'video_decoder_preference=${nextSettings.videoDecoderPreference} '
            'console_log_enabled=${nextSettings.consoleLogEnabled}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
    } on Object catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        'example_settings_save_failed reason=$reason error=$error',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = previousSettings;
        _saving = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('设置保存失败。')));
    }
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ExampleTheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ExampleTheme.surface.withAlpha(224),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ExampleTheme.primary.withAlpha(31)),
      ),
      child: child,
    );
  }
}

class _DecoderPreferenceSheet extends StatelessWidget {
  const _DecoderPreferenceSheet({required this.currentPreference});

  final int currentPreference;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '视频解码偏好',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: currentPreference,
              onChanged: (int? value) {
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _DecoderPreferenceTile(value: DemoExampleSettings.videoDecoderPreferenceAuto),
                  _DecoderPreferenceTile(value: DemoExampleSettings.videoDecoderPreferenceHardware),
                  _DecoderPreferenceTile(value: DemoExampleSettings.videoDecoderPreferenceSoftware),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecoderPreferenceTile extends StatelessWidget {
  const _DecoderPreferenceTile({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<int>(
      value: value,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(DemoExampleSettings.videoDecoderPreferenceLabel(value)),
    );
  }
}
