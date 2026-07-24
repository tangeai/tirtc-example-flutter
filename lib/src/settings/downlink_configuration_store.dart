import 'package:tirtc_flutter/tirtc_flutter.dart';

import 'example_preferences.dart';

final class DemoDownlinkConfigurationSnapshot {
  const DemoDownlinkConfigurationSnapshot({
    this.appId = '',
    this.endpoint = '',
    this.remoteId = '',
    this.audioStreamId = '',
    this.videoStreamId = '',
  });

  final String appId;
  final String endpoint;
  final String remoteId;
  final String audioStreamId;
  final String videoStreamId;
}

final class DemoDownlinkConfigurationStore {
  const DemoDownlinkConfigurationStore({
    this.preferences = const MethodChannelDemoExamplePreferences(),
  });

  static const String appIdKey = 'tirtc_example.downlink.app_id';
  static const String endpointKey = 'tirtc_example.downlink.endpoint';
  static const String remoteIdKey = 'tirtc_example.downlink.remote_id';
  static const String audioStreamIdKey = 'tirtc_example.downlink.audio_stream_id';
  static const String videoStreamIdKey = 'tirtc_example.downlink.video_stream_id';

  final DemoExamplePreferences preferences;

  Future<DemoDownlinkConfigurationSnapshot> load() async {
    return DemoDownlinkConfigurationSnapshot(
      appId: await _readString(appIdKey),
      endpoint: await _readString(endpointKey),
      remoteId: await _readString(remoteIdKey),
      audioStreamId: await _readString(audioStreamIdKey),
      videoStreamId: await _readString(videoStreamIdKey),
    );
  }

  Future<void> save(DemoDownlinkConfigurationSnapshot snapshot) async {
    await preferences.putString(key: appIdKey, value: snapshot.appId);
    await preferences.putString(key: endpointKey, value: snapshot.endpoint);
    await preferences.putString(key: remoteIdKey, value: snapshot.remoteId);
    await preferences.putString(key: audioStreamIdKey, value: snapshot.audioStreamId);
    await preferences.putString(key: videoStreamIdKey, value: snapshot.videoStreamId);
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
}
