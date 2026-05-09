import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../demo_configuration.dart';
import 'example_preferences.dart';

final class DemoExampleSettingsStore {
  const DemoExampleSettingsStore({
    this.preferences = const MethodChannelDemoExamplePreferences(),
  });

  static const String videoDecoderPreferenceKey = 'tirtc_av_kit_example.settings.video_decoder_preference';
  static const String consoleLogEnabledKey = 'tirtc_av_kit_example.settings.console_log_enabled';

  final DemoExamplePreferences preferences;

  Future<DemoExampleSettings> load({
    int? testVideoDecoderPreference,
  }) async {
    final DemoExampleSettings manualSettings = await _loadManualSettings();
    if (testVideoDecoderPreference == null) {
      return manualSettings;
    }

    return DemoExampleSettings(
      videoDecoderPreference: _validVideoDecoderPreferenceOrDefault(
        testVideoDecoderPreference,
      ),
      consoleLogEnabled: true,
    );
  }

  Future<void> save(DemoExampleSettings settings) async {
    await preferences.putInt(
      key: videoDecoderPreferenceKey,
      value: _validVideoDecoderPreferenceOrDefault(settings.videoDecoderPreference),
    );
    await preferences.putInt(
      key: consoleLogEnabledKey,
      value: settings.consoleLogEnabled ? 1 : 0,
    );
  }

  Future<DemoExampleSettings> _loadManualSettings() async {
    final int videoDecoderPreference = await _readInt(
      key: videoDecoderPreferenceKey,
      defaultValue: DemoExampleSettings.videoDecoderPreferenceAuto,
    );
    final int consoleLogEnabled = await _readInt(
      key: consoleLogEnabledKey,
      defaultValue: 0,
    );

    return DemoExampleSettings(
      videoDecoderPreference: _validVideoDecoderPreferenceOrDefault(videoDecoderPreference),
      consoleLogEnabled: consoleLogEnabled == 1,
    );
  }

  Future<int> _readInt({
    required String key,
    required int defaultValue,
  }) async {
    try {
      return await preferences.getInt(key: key, defaultValue: defaultValue);
    } on Object catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        'example_settings_read_failed key=$key error=$error',
      );
      return defaultValue;
    }
  }

  static int _validVideoDecoderPreferenceOrDefault(int value) {
    if (DemoExampleSettings.isValidVideoDecoderPreference(value)) {
      return value;
    }
    return DemoExampleSettings.videoDecoderPreferenceAuto;
  }
}
