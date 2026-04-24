import 'dart:convert';

final class DemoPlaybackConfiguration {
  static const int defaultAudioStreamId = 10;
  static const int defaultVideoStreamId = 11;

  const DemoPlaybackConfiguration({
    required this.appId,
    required this.endpoint,
    required this.remoteId,
    required this.audioStreamId,
    required this.videoStreamId,
    required this.token,
  });

  final String appId;
  final String endpoint;
  final String remoteId;
  final int audioStreamId;
  final int videoStreamId;
  final String token;
}

final class DemoScanPayload {
  const DemoScanPayload({
    required this.appId,
    required this.remoteId,
    required this.token,
    this.endpoint,
  });

  final String appId;
  final String remoteId;
  final String token;
  final String? endpoint;

  static DemoScanPayload? tryParse(String rawValue) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_normalizeJson(rawValue));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<Object?, Object?>) {
      return null;
    }

    final Map<Object?, Object?> payload = decoded;
    final String appId = _stringValue(payload['app_id']);
    final String remoteId = _stringValue(payload['remote_id']);
    final String token = _stringValue(payload['token']);
    final String? endpoint = payload.containsKey('endpoint') ? _stringValue(payload['endpoint']) : null;
    if (appId.isEmpty || remoteId.isEmpty || token.isEmpty) {
      return null;
    }
    return DemoScanPayload(
      appId: appId,
      remoteId: remoteId,
      token: token,
      endpoint: endpoint,
    );
  }

  static String _normalizeJson(String rawValue) {
    return rawValue.replaceAll(RegExp(r',\s*}'), '}').replaceAll(RegExp(r',\s*]'), ']');
  }

  static String _stringValue(Object? value) {
    return switch (value) {
      final String text => text.trim(),
      _ => '',
    };
  }
}
