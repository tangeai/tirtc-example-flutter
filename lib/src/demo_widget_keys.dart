import 'package:flutter/widgets.dart';

abstract final class DemoWidgetKeys {
  static const ValueKey<String> playerPage = ValueKey<String>('tirtc_example_player_page');
  static const ValueKey<String> deviceServerPage = ValueKey<String>('tirtc_example_device_server_page');
  static const ValueKey<String> playerCommandButton = ValueKey<String>('tirtc_example_player_command_button');
  static const ValueKey<String> playerLogUploadButton = ValueKey<String>('tirtc_example_player_log_upload_button');
  static const ValueKey<String> openDeviceServerButton = ValueKey<String>('tirtc_example_open_device_server_button');
  static const ValueKey<String> startDownlinkButton = ValueKey<String>('tirtc_example_start_downlink_button');
  static const ValueKey<String> endpointField = ValueKey<String>('tirtc_example_endpoint_field');
  static const ValueKey<String> appIdField = ValueKey<String>('tirtc_example_app_id_field');
  static const ValueKey<String> remoteIdField = ValueKey<String>('tirtc_example_remote_id_field');
  static const ValueKey<String> audioStreamIdField = ValueKey<String>('tirtc_example_audio_stream_id_field');
  static const ValueKey<String> videoStreamIdField = ValueKey<String>('tirtc_example_video_stream_id_field');
  static const ValueKey<String> tokenField = ValueKey<String>('tirtc_example_token_field');
  static const ValueKey<String> deviceEndpointField = ValueKey<String>('tirtc_example_device_endpoint_field');
  static const ValueKey<String> deviceIdField = ValueKey<String>('tirtc_example_device_id_field');
  static const ValueKey<String> deviceSecretKeyField = ValueKey<String>('tirtc_example_device_secret_key_field');
  static const ValueKey<String> startDeviceServerButton = ValueKey<String>('tirtc_example_start_device_server_button');
}
