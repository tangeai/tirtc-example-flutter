import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../demo_configuration.dart';
import 'example_preferences.dart';

final class DemoDownlinkConfigurationSnapshot {
  const DemoDownlinkConfigurationSnapshot({
    this.appId = '',
    this.endpoint = '',
    this.remoteId = '',
    this.audioStreamId = '',
    this.videoStreamId = '',
    this.tokenIssuerBaseUrl = '',
  });

  final String appId;
  final String endpoint;
  final String remoteId;
  final String audioStreamId;
  final String videoStreamId;
  final String tokenIssuerBaseUrl;
}

final class DemoDownlinkConfigurationStore {
  const DemoDownlinkConfigurationStore({
    this.preferences = const MethodChannelDemoExamplePreferences(),
  });

  static const String appIdKey = 'tirtc_av_kit_example.downlink.app_id';
  static const String endpointKey = 'tirtc_av_kit_example.downlink.endpoint';
  static const String remoteIdKey = 'tirtc_av_kit_example.downlink.remote_id';
  static const String audioStreamIdKey = 'tirtc_av_kit_example.downlink.audio_stream_id';
  static const String videoStreamIdKey = 'tirtc_av_kit_example.downlink.video_stream_id';
  static const String tokenIssuerBaseUrlKey = 'tirtc_av_kit_example.downlink.token_issuer_base_url';
  static const String legacyTokenIssuerUrlKey = 'tirtc_av_kit_example.downlink.token_issuer_url';

  final DemoExamplePreferences preferences;

  Future<DemoDownlinkConfigurationSnapshot> load() async {
    return DemoDownlinkConfigurationSnapshot(
      appId: await _readString(appIdKey),
      endpoint: await _readString(endpointKey),
      remoteId: await _readString(remoteIdKey),
      audioStreamId: await _readString(audioStreamIdKey),
      videoStreamId: await _readString(videoStreamIdKey),
      tokenIssuerBaseUrl: await _readTokenIssuerBaseUrl(),
    );
  }

  Future<void> save(DemoDownlinkConfigurationSnapshot snapshot) async {
    await preferences.putString(key: appIdKey, value: snapshot.appId);
    await preferences.putString(key: endpointKey, value: snapshot.endpoint);
    await preferences.putString(key: remoteIdKey, value: snapshot.remoteId);
    await preferences.putString(key: audioStreamIdKey, value: snapshot.audioStreamId);
    await preferences.putString(key: videoStreamIdKey, value: snapshot.videoStreamId);
    await preferences.putString(key: tokenIssuerBaseUrlKey, value: snapshot.tokenIssuerBaseUrl);
  }

  Future<String> _readString(String key) async {
    try {
      return await preferences.getString(key: key, defaultValue: '');
    } on Object catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        'downlink_preferences_read_failed key=$key error=$error',
      );
      return '';
    }
  }

  Future<String> _readTokenIssuerBaseUrl() async {
    final String storedBaseUrl = await _readString(tokenIssuerBaseUrlKey);
    if (storedBaseUrl.trim().isNotEmpty) {
      return _normalizedStoredTokenIssuerBaseUrl(storedBaseUrl);
    }
    final String legacyUrl = await _readString(legacyTokenIssuerUrlKey);
    return _normalizedStoredTokenIssuerBaseUrl(legacyUrl);
  }

  String _normalizedStoredTokenIssuerBaseUrl(String value) {
    if (value.trim().isEmpty) {
      return '';
    }
    try {
      return normalizeDemoTokenIssuerBaseUrl(value);
    } on FormatException {
      return value.trim();
    }
  }
}
