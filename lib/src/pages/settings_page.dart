import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';
import '../settings/demo_example_settings_store.dart';
import '../settings/device_server_configuration_store.dart';
import '../widgets/settings_page_widgets.dart';

class DemoSettingsPage extends StatefulWidget {
  const DemoSettingsPage({
    super.key,
    required this.initialSettings,
    this.settingsStore = const DemoExampleSettingsStore(),
    this.deviceSettingsStore = const DemoDeviceServerConfigurationStore(),
  });

  final DemoExampleSettings initialSettings;
  final DemoExampleSettingsStore settingsStore;
  final DemoDeviceServerConfigurationStore deviceSettingsStore;

  @override
  State<DemoSettingsPage> createState() => _DemoSettingsPageState();
}

class _DemoSettingsPageState extends State<DemoSettingsPage> {
  late DemoExampleSettings _settings = widget.initialSettings;
  DemoDeviceCameraFacing _deviceCameraFacing = DemoDeviceCameraFacing.back;
  DemoDeviceVideoCodec _deviceVideoCodec = DemoDeviceVideoCodec.h264;
  DemoDeviceEncoderPreference _deviceEncoderPreference = DemoDeviceEncoderPreference.hardware;
  bool _saving = false;
  bool _devicePreferencesLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDevicePreferences());
  }

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
              const SettingsSectionTitle(label: '客户端'),
              SettingsSurface(
                child: Column(
                  children: <Widget>[
                    ListTile(
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
                    const Divider(height: 1, indent: 16, endIndent: 16, color: ExampleTheme.inputBorder),
                    ListTile(
                      enabled: !_saving,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('输出缓冲策略'),
                      subtitle: Text(
                        DemoExampleSettings.outputBufferPolicyLabel(_settings.outputBufferPolicy),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ExampleTheme.textSecondary,
                      ),
                      onTap: _saving
                          ? null
                          : () {
                              unawaited(_chooseOutputBufferPolicy());
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SettingsSectionTitle(label: '本地音频采集与传输'),
              SettingsSurface(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      enabled: !_saving,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('编码格式'),
                      subtitle: Text(DemoExampleSettings.localAudioCodecLabel(_settings.localAudioCodec)),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ExampleTheme.textSecondary,
                      ),
                      onTap: _saving
                          ? null
                          : () {
                              unawaited(_chooseLocalAudioCodec());
                            },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: ExampleTheme.inputBorder),
                    ListTile(
                      enabled: !_saving,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('采样率'),
                      subtitle: Text(DemoExampleSettings.localAudioSampleRateLabel(_settings.localAudioSampleRateHz)),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ExampleTheme.textSecondary,
                      ),
                      onTap: _saving
                          ? null
                          : () {
                              unawaited(_chooseLocalAudioSampleRate());
                            },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: ExampleTheme.inputBorder),
                    ListTile(
                      enabled: !_saving,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('传输 Stream ID'),
                      subtitle: Text('${_settings.localAudioStreamId}'),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ExampleTheme.textSecondary,
                      ),
                      onTap: _saving
                          ? null
                          : () {
                              unawaited(_chooseLocalAudioStreamId());
                            },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: ExampleTheme.inputBorder),
                    SwitchListTile(
                      value: _settings.localAudioAecEnabled,
                      onChanged: _saving
                          ? null
                          : (bool value) {
                              unawaited(_setLocalAudioAecEnabled(value));
                            },
                      // ignore: deprecated_member_use
                      activeColor: ExampleTheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('AEC'),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: ExampleTheme.inputBorder),
                    ListTile(
                      enabled: !_saving,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('AGC'),
                      subtitle: Text(DemoExampleSettings.localAudioProcessingLevelLabel(_settings.localAudioAgcLevel)),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ExampleTheme.textSecondary,
                      ),
                      onTap: _saving
                          ? null
                          : () {
                              unawaited(_chooseLocalAudioAgcLevel());
                            },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: ExampleTheme.inputBorder),
                    ListTile(
                      enabled: !_saving,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('ANS'),
                      subtitle: Text(DemoExampleSettings.localAudioProcessingLevelLabel(_settings.localAudioAnsLevel)),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ExampleTheme.textSecondary,
                      ),
                      onTap: _saving
                          ? null
                          : () {
                              unawaited(_chooseLocalAudioAnsLevel());
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SettingsSectionTitle(label: '设备端'),
              SettingsSurface(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      enabled: !_saving && _devicePreferencesLoaded,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('摄像头'),
                      subtitle: Text(_deviceCameraFacingLabel(_deviceCameraFacing)),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ExampleTheme.textSecondary,
                      ),
                      onTap: _saving || !_devicePreferencesLoaded
                          ? null
                          : () {
                              unawaited(_chooseDeviceCameraFacing());
                            },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: ExampleTheme.inputBorder),
                    ListTile(
                      enabled: !_saving && _devicePreferencesLoaded,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('编码格式'),
                      subtitle: Text(_deviceVideoCodecLabel(_deviceVideoCodec)),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ExampleTheme.textSecondary,
                      ),
                      onTap: _saving || !_devicePreferencesLoaded
                          ? null
                          : () {
                              unawaited(_chooseDeviceVideoCodec());
                            },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: ExampleTheme.inputBorder),
                    ListTile(
                      enabled: !_saving && _devicePreferencesLoaded && _deviceVideoCodec == DemoDeviceVideoCodec.h264,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('编码模式'),
                      subtitle: Text(_deviceEncoderPreferenceSubtitle()),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ExampleTheme.textSecondary,
                      ),
                      onTap: _saving || !_devicePreferencesLoaded || _deviceVideoCodec != DemoDeviceVideoCodec.h264
                          ? null
                          : () {
                              unawaited(_chooseDeviceEncoderPreference());
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SettingsSectionTitle(label: '通用'),
              SettingsSurface(
                child: SwitchListTile(
                  value: _settings.consoleLogEnabled,
                  onChanged: _saving
                      ? null
                      : (bool value) {
                          unawaited(_setConsoleLogEnabled(value));
                        },
                  // ignore: deprecated_member_use
                  activeColor: ExampleTheme.primary,
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

  Future<void> _loadDevicePreferences() async {
    final DemoDeviceServerConfigurationSnapshot snapshot = await widget.deviceSettingsStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceCameraFacing = snapshot.cameraFacing;
      _deviceVideoCodec = snapshot.videoCodec;
      _deviceEncoderPreference = snapshot.encoderPreference;
      _devicePreferencesLoaded = true;
    });
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
        return PreferenceSheet<int>(
          title: '视频解码偏好',
          currentValue: _settings.videoDecoderPreference,
          options: const <PreferenceOption<int>>[
            PreferenceOption<int>(
              value: DemoExampleSettings.videoDecoderPreferenceAuto,
              label: '自动',
            ),
            PreferenceOption<int>(
              value: DemoExampleSettings.videoDecoderPreferenceHardware,
              label: '硬解',
            ),
            PreferenceOption<int>(
              value: DemoExampleSettings.videoDecoderPreferenceSoftware,
              label: '软解',
            ),
          ],
        );
      },
    );
    if (!mounted || value == null) {
      return;
    }
    await _setVideoDecoderPreference(value);
  }

  Future<void> _setOutputBufferPolicy(String? value) async {
    if (value == null || !DemoExampleSettings.isValidOutputBufferPolicy(value)) {
      return;
    }
    if (value == _settings.outputBufferPolicy) {
      return;
    }
    await _saveSettings(
      _settings.copyWith(outputBufferPolicy: value),
      reason: 'output_buffer_policy',
    );
  }

  Future<void> _chooseOutputBufferPolicy() async {
    final String? value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: ExampleTheme.background,
      builder: (BuildContext context) {
        return PreferenceSheet<String>(
          title: '输出缓冲策略',
          currentValue: _settings.outputBufferPolicy,
          options: const <PreferenceOption<String>>[
            PreferenceOption<String>(
              value: DemoExampleSettings.outputBufferPolicyAutomatic,
              label: '自动',
            ),
            PreferenceOption<String>(
              value: DemoExampleSettings.outputBufferPolicyNoBuffer,
              label: '不缓冲',
            ),
          ],
        );
      },
    );
    if (!mounted || value == null) {
      return;
    }
    await _setOutputBufferPolicy(value);
  }

  Future<void> _chooseLocalAudioCodec() async {
    final String? value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: ExampleTheme.background,
      builder: (BuildContext context) {
        return PreferenceSheet<String>(
          title: '编码格式',
          currentValue: _settings.localAudioCodec,
          options: const <PreferenceOption<String>>[
            PreferenceOption<String>(
              value: DemoExampleSettings.localAudioCodecG711a,
              label: 'G711A',
            ),
            PreferenceOption<String>(
              value: DemoExampleSettings.localAudioCodecAac,
              label: 'AAC',
            ),
            PreferenceOption<String>(
              value: DemoExampleSettings.localAudioCodecPcm,
              label: 'PCM',
            ),
          ],
        );
      },
    );
    if (!mounted || value == null || !DemoExampleSettings.isValidLocalAudioCodec(value)) {
      return;
    }
    await _saveSettings(
      _settings.copyWith(localAudioCodec: value),
      reason: 'local_audio_codec',
    );
  }

  Future<void> _chooseLocalAudioSampleRate() async {
    final int? value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: ExampleTheme.background,
      builder: (BuildContext context) {
        return PreferenceSheet<int>(
          title: '采样率',
          currentValue: _settings.localAudioSampleRateHz,
          options: const <PreferenceOption<int>>[
            PreferenceOption<int>(
              value: DemoExampleSettings.localAudioSampleRate8k,
              label: '8 kHz',
            ),
            PreferenceOption<int>(
              value: DemoExampleSettings.localAudioSampleRate16k,
              label: '16 kHz',
            ),
          ],
        );
      },
    );
    if (!mounted || value == null || !DemoExampleSettings.isValidLocalAudioSampleRate(value)) {
      return;
    }
    await _saveSettings(
      _settings.copyWith(localAudioSampleRateHz: value),
      reason: 'local_audio_sample_rate',
    );
  }

  Future<void> _chooseLocalAudioStreamId() async {
    final TextEditingController controller = TextEditingController(text: '${_settings.localAudioStreamId}');
    final int? value = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('传输 Stream ID'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '1-255',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(int.tryParse(controller.text.trim()));
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || value == null || !DemoExampleSettings.isValidLocalAudioStreamId(value)) {
      return;
    }
    await _saveSettings(
      _settings.copyWith(localAudioStreamId: value),
      reason: 'local_audio_stream_id',
    );
  }

  Future<void> _setLocalAudioAecEnabled(bool value) async {
    await _saveSettings(
      _settings.copyWith(localAudioAecEnabled: value),
      reason: 'local_audio_aec',
    );
  }

  Future<void> _chooseLocalAudioAgcLevel() async {
    final int? value = await _chooseLocalAudioProcessingLevel(
      title: 'AGC',
      currentValue: _settings.localAudioAgcLevel,
    );
    if (!mounted || value == null || !DemoExampleSettings.isValidLocalAudioProcessingLevel(value)) {
      return;
    }
    await _saveSettings(
      _settings.copyWith(localAudioAgcLevel: value),
      reason: 'local_audio_agc',
    );
  }

  Future<void> _chooseLocalAudioAnsLevel() async {
    final int? value = await _chooseLocalAudioProcessingLevel(
      title: 'ANS',
      currentValue: _settings.localAudioAnsLevel,
    );
    if (!mounted || value == null || !DemoExampleSettings.isValidLocalAudioProcessingLevel(value)) {
      return;
    }
    await _saveSettings(
      _settings.copyWith(localAudioAnsLevel: value),
      reason: 'local_audio_ans',
    );
  }

  Future<int?> _chooseLocalAudioProcessingLevel({
    required String title,
    required int currentValue,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: ExampleTheme.background,
      builder: (BuildContext context) {
        return PreferenceSheet<int>(
          title: title,
          currentValue: currentValue,
          options: const <PreferenceOption<int>>[
            PreferenceOption<int>(value: 0, label: '关闭'),
            PreferenceOption<int>(value: 1, label: '低'),
            PreferenceOption<int>(value: 2, label: '中'),
            PreferenceOption<int>(value: 3, label: '高'),
          ],
        );
      },
    );
  }

  Future<void> _setConsoleLogEnabled(bool value) async {
    await _saveSettings(
      _settings.copyWith(consoleLogEnabled: value),
      reason: 'console_log_enabled',
    );
  }

  Future<void> _chooseDeviceCameraFacing() async {
    final DemoDeviceCameraFacing? value = await showModalBottomSheet<DemoDeviceCameraFacing>(
      context: context,
      showDragHandle: true,
      backgroundColor: ExampleTheme.background,
      builder: (BuildContext context) {
        return PreferenceSheet<DemoDeviceCameraFacing>(
          title: '摄像头',
          currentValue: _deviceCameraFacing,
          options: const <PreferenceOption<DemoDeviceCameraFacing>>[
            PreferenceOption<DemoDeviceCameraFacing>(
              value: DemoDeviceCameraFacing.front,
              label: '前置',
            ),
            PreferenceOption<DemoDeviceCameraFacing>(
              value: DemoDeviceCameraFacing.back,
              label: '后置',
            ),
          ],
        );
      },
    );
    if (!mounted || value == null) {
      return;
    }
    await _saveDevicePreferences(cameraFacing: value, reason: 'device_camera_facing');
  }

  Future<void> _chooseDeviceVideoCodec() async {
    final DemoDeviceVideoCodec? value = await showModalBottomSheet<DemoDeviceVideoCodec>(
      context: context,
      showDragHandle: true,
      backgroundColor: ExampleTheme.background,
      builder: (BuildContext context) {
        return PreferenceSheet<DemoDeviceVideoCodec>(
          title: '编码格式',
          currentValue: _deviceVideoCodec,
          options: const <PreferenceOption<DemoDeviceVideoCodec>>[
            PreferenceOption<DemoDeviceVideoCodec>(
              value: DemoDeviceVideoCodec.h264,
              label: 'H264',
            ),
            PreferenceOption<DemoDeviceVideoCodec>(
              value: DemoDeviceVideoCodec.mjpeg,
              label: 'MJPEG',
            ),
          ],
        );
      },
    );
    if (!mounted || value == null) {
      return;
    }
    await _saveDevicePreferences(videoCodec: value, reason: 'device_video_codec');
  }

  Future<void> _chooseDeviceEncoderPreference() async {
    final DemoDeviceEncoderPreference? value = await showModalBottomSheet<DemoDeviceEncoderPreference>(
      context: context,
      showDragHandle: true,
      backgroundColor: ExampleTheme.background,
      builder: (BuildContext context) {
        return PreferenceSheet<DemoDeviceEncoderPreference>(
          title: '编码模式',
          currentValue: _deviceEncoderPreference,
          options: const <PreferenceOption<DemoDeviceEncoderPreference>>[
            PreferenceOption<DemoDeviceEncoderPreference>(
              value: DemoDeviceEncoderPreference.software,
              label: '软编',
            ),
            PreferenceOption<DemoDeviceEncoderPreference>(
              value: DemoDeviceEncoderPreference.hardware,
              label: '硬编',
            ),
          ],
        );
      },
    );
    if (!mounted || value == null) {
      return;
    }
    await _saveDevicePreferences(encoderPreference: value, reason: 'device_encoder_preference');
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
            'output_buffer_policy=${nextSettings.outputBufferPolicy} '
            'console_log_enabled=${nextSettings.consoleLogEnabled} '
            'local_audio_codec=${nextSettings.localAudioCodec} '
            'local_audio_sample_rate_hz=${nextSettings.localAudioSampleRateHz} '
            'local_audio_stream_id=${nextSettings.localAudioStreamId} '
            'local_audio_aec=${nextSettings.localAudioAecEnabled} '
            'local_audio_agc_level=${nextSettings.localAudioAgcLevel} '
            'local_audio_ans_level=${nextSettings.localAudioAnsLevel}',
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

  Future<void> _saveDevicePreferences({
    DemoDeviceCameraFacing? cameraFacing,
    DemoDeviceVideoCodec? videoCodec,
    DemoDeviceEncoderPreference? encoderPreference,
    required String reason,
  }) async {
    final DemoDeviceCameraFacing previousCameraFacing = _deviceCameraFacing;
    final DemoDeviceVideoCodec previousVideoCodec = _deviceVideoCodec;
    final DemoDeviceEncoderPreference previousEncoderPreference = _deviceEncoderPreference;
    final DemoDeviceCameraFacing nextCameraFacing = cameraFacing ?? _deviceCameraFacing;
    final DemoDeviceVideoCodec nextVideoCodec = videoCodec ?? _deviceVideoCodec;
    final DemoDeviceEncoderPreference nextEncoderPreference = nextVideoCodec == DemoDeviceVideoCodec.mjpeg
        ? DemoDeviceEncoderPreference.software
        : encoderPreference ?? _deviceEncoderPreference;
    if (nextCameraFacing == previousCameraFacing &&
        nextVideoCodec == previousVideoCodec &&
        nextEncoderPreference == previousEncoderPreference) {
      return;
    }

    setState(() {
      _deviceCameraFacing = nextCameraFacing;
      _deviceVideoCodec = nextVideoCodec;
      _deviceEncoderPreference = nextEncoderPreference;
      _saving = true;
    });

    try {
      await widget.deviceSettingsStore.saveDevicePreferences(
        cameraFacing: nextCameraFacing,
        videoCodec: nextVideoCodec,
        encoderPreference: nextEncoderPreference,
      );
      TiRtcLogging.i(
        'flutter_example',
        'device_preferences_saved reason=$reason '
            'camera_facing=${nextCameraFacing.name} '
            'video_codec=${nextVideoCodec.name} '
            'encoder_preference=${nextEncoderPreference.name}',
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
        'device_preferences_save_failed reason=$reason error=$error',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _deviceCameraFacing = previousCameraFacing;
        _deviceVideoCodec = previousVideoCodec;
        _deviceEncoderPreference = previousEncoderPreference;
        _saving = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('设备端设置保存失败。')));
    }
  }

  String _deviceCameraFacingLabel(DemoDeviceCameraFacing value) {
    return switch (value) {
      DemoDeviceCameraFacing.front => '前置',
      DemoDeviceCameraFacing.back => '后置',
    };
  }

  String _deviceVideoCodecLabel(DemoDeviceVideoCodec value) {
    return switch (value) {
      DemoDeviceVideoCodec.h264 => 'H264',
      DemoDeviceVideoCodec.h265 => 'H265',
      DemoDeviceVideoCodec.mjpeg => 'MJPEG',
    };
  }

  String _deviceEncoderPreferenceLabel(DemoDeviceEncoderPreference value) {
    return switch (value) {
      DemoDeviceEncoderPreference.software => '软编',
      DemoDeviceEncoderPreference.hardware => '硬编',
    };
  }

  String _deviceEncoderPreferenceSubtitle() {
    final String label = _deviceEncoderPreferenceLabel(_deviceEncoderPreference);
    if (_deviceVideoCodec == DemoDeviceVideoCodec.mjpeg) {
      return '$label（MJPEG 仅支持软编）';
    }
    return label;
  }
}
