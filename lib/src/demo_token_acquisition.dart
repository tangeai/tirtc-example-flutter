import 'dart:async';
import 'dart:convert';

final class DemoTokenAcquirer {
  const DemoTokenAcquirer();

  Future<String> resolve({
    required String token,
  }) {
    return Future<String>.value(normalizeDemoConnectionToken(token));
  }
}

String normalizeDemoConnectionToken(String rawValue) {
  final String token = rawValue.trim();
  if (!demoConnectionTokenLooksValid(token)) {
    throw const FormatException('token must start with v1.');
  }
  return token;
}

bool demoConnectionTokenLooksValid(String value) {
  return value.trim().startsWith('v1.');
}

final class DemoScanPayload {
  const DemoScanPayload({
    required this.token,
    this.appId,
    this.remoteId,
    this.endpoint,
  });

  final String token;
  final String? appId;
  final String? remoteId;
  final String? endpoint;

  bool get hasConnectionFields => appId != null && remoteId != null;

  static const Set<String> _allowedPayloadKeys = <String>{
    'app_id',
    'remote_id',
    'endpoint',
    'token',
  };

  static DemoScanPayload? tryParse(String rawValue) {
    final String text = rawValue.trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.startsWith('{')) {
      return _tryParseJson(text);
    }
    if (demoConnectionTokenLooksValid(text)) {
      return DemoScanPayload(token: normalizeDemoConnectionToken(text));
    }
    return null;
  }

  static DemoScanPayload? _tryParseJson(String rawValue) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_normalizeJson(rawValue));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<Object?, Object?>) {
      return null;
    }

    for (final Object? key in decoded.keys) {
      if (key is! String || !_allowedPayloadKeys.contains(key)) {
        return null;
      }
    }

    final String appId = _stringValue(decoded['app_id']);
    final String remoteId = _stringValue(decoded['remote_id']);
    final String token = _stringValue(decoded['token']);
    final Object? rawEndpoint = decoded['endpoint'];
    if (appId.isEmpty || remoteId.isEmpty || token.isEmpty) {
      return null;
    }
    if (!demoConnectionTokenLooksValid(token)) {
      return null;
    }
    if (decoded.containsKey('endpoint') && rawEndpoint != null && rawEndpoint is! String) {
      return null;
    }
    final String? endpoint = rawEndpoint is String ? rawEndpoint.trim() : null;
    if (endpoint != null && endpoint.isNotEmpty && !_validEndpoint(endpoint)) {
      return null;
    }
    return DemoScanPayload(
      appId: appId,
      remoteId: remoteId,
      token: normalizeDemoConnectionToken(token),
      endpoint: endpoint == null || endpoint.isEmpty ? null : endpoint,
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

bool _validEndpoint(String text) {
  if (text.isEmpty) {
    return true;
  }
  final Uri? uri = Uri.tryParse(text);
  return uri != null && uri.host.isNotEmpty && (uri.scheme == 'http' || uri.scheme == 'https');
}
