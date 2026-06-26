import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int demoTokenRequestByteLimit = 8192;
const Duration demoTokenRequestTimeout = Duration(seconds: 10);
const String demoTokenIssuerTokenPath = '/v1/tokens';

enum DemoTokenSource {
  issuer,
  oneTime;
}

final class DemoTokenSourceConfiguration {
  const DemoTokenSourceConfiguration({
    required this.source,
    required this.tokenIssuerBaseUrl,
    required this.oneTimeToken,
  });

  final DemoTokenSource source;
  final String tokenIssuerBaseUrl;
  final String oneTimeToken;
}

final class DemoTokenHttpRequest {
  const DemoTokenHttpRequest({
    required this.uri,
    required this.method,
    this.jsonBody,
  });

  final Uri uri;
  final String method;
  final Object? jsonBody;
}

final class DemoTokenHttpResponse {
  const DemoTokenHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

typedef DemoTokenHttpClient = Future<DemoTokenHttpResponse> Function(DemoTokenHttpRequest request);

final class DemoTokenAcquirer {
  const DemoTokenAcquirer({
    this.httpClient = demoDefaultTokenHttpClient,
  });

  final DemoTokenHttpClient httpClient;

  Future<String> resolve({
    required DemoTokenSourceConfiguration configuration,
    required String remoteId,
  }) {
    return switch (configuration.source) {
      DemoTokenSource.issuer => _resolveIssuer(
          baseUrl: configuration.tokenIssuerBaseUrl,
          remoteId: remoteId,
        ),
      DemoTokenSource.oneTime => _resolveOneTime(configuration.oneTimeToken),
    };
  }

  Future<String> _resolveIssuer({
    required String baseUrl,
    required String remoteId,
  }) async {
    final DemoTokenHttpRequest request = demoTokenIssuerRequest(
      baseUrl,
      remoteId: remoteId,
    );
    final DemoTokenHttpResponse response = await httpClient(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('issuer returned HTTP ${response.statusCode}');
    }
    return parseDemoTokenIssuerResponse(response.body);
  }

  Future<String> _resolveOneTime(String rawToken) {
    return Future<String>.value(normalizeDemoConnectionToken(rawToken));
  }
}

String parseDemoTokenIssuerResponse(String body) {
  final String value = body.trim();
  if (demoConnectionTokenLooksValid(value)) {
    return normalizeDemoConnectionToken(value);
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    throw StateError('issuer response is not a token or JSON object');
  }

  if (decoded is! Map<String, Object?>) {
    throw StateError('issuer response is not an object');
  }
  final Object? token = decoded['token'];
  if (token is! String) {
    throw StateError('issuer response missing token');
  }
  return normalizeDemoConnectionToken(token);
}

DemoTokenHttpRequest demoTokenIssuerRequest(String rawValue, {required String remoteId}) {
  final Uri uri = _normalizeDemoTokenIssuerUri(rawValue);
  if (_isFixedPathIssuerAddress(uri)) {
    return DemoTokenHttpRequest(
      uri: _fixedPathIssuerTokenUri(uri),
      method: 'POST',
      jsonBody: <String, String>{'remote_id': remoteId},
    );
  }
  return DemoTokenHttpRequest(uri: uri, method: 'GET');
}

Future<DemoTokenHttpResponse> demoDefaultTokenHttpClient(DemoTokenHttpRequest request) async {
  final HttpClient client = HttpClient();
  client.connectionTimeout = demoTokenRequestTimeout;
  try {
    final HttpClientRequest httpRequest;
    if (request.method == 'POST') {
      httpRequest = await client.postUrl(request.uri).timeout(demoTokenRequestTimeout);
    } else {
      httpRequest = await client.getUrl(request.uri).timeout(demoTokenRequestTimeout);
    }
    if (request.jsonBody != null) {
      httpRequest.headers.contentType = ContentType.json;
      httpRequest.write(jsonEncode(request.jsonBody));
    }

    final HttpClientResponse response = await httpRequest.close().timeout(demoTokenRequestTimeout);
    final List<int> bytes = await response.take(demoTokenRequestByteLimit + 1).fold<List<int>>(
      <int>[],
      (List<int> previous, List<int> chunk) => previous..addAll(chunk),
    );
    if (bytes.length > demoTokenRequestByteLimit) {
      throw StateError('token response too large');
    }
    return DemoTokenHttpResponse(
      statusCode: response.statusCode,
      body: utf8.decode(bytes),
    );
  } finally {
    client.close(force: true);
  }
}

String normalizeDemoTokenIssuerBaseUrl(String rawValue) {
  final Uri uri = _normalizeDemoTokenIssuerUri(rawValue);
  if (_isFixedPathIssuerAddress(uri)) {
    return _issuerOrigin(uri).toString();
  }
  return uri.toString();
}

Uri demoTokenIssuerTokenUri(String baseUrl) {
  final Uri uri = _normalizeDemoTokenIssuerUri(baseUrl);
  if (_isFixedPathIssuerAddress(uri)) {
    return _fixedPathIssuerTokenUri(uri);
  }
  return uri;
}

Uri _normalizeDemoTokenIssuerUri(String rawValue) {
  final String value = rawValue.trim();
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw const FormatException('token issuer address must be a full http(s) URL');
  }
  if (uri.userInfo.isNotEmpty || uri.hasFragment) {
    throw const FormatException('token issuer address must not include user info or fragment');
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: _normalizedPort(uri),
    path: uri.path,
    query: uri.hasQuery ? uri.query : null,
  );
}

bool _isFixedPathIssuerAddress(Uri uri) {
  return !uri.hasQuery && (uri.path.isEmpty || uri.path == '/' || uri.path == demoTokenIssuerTokenPath);
}

Uri _fixedPathIssuerTokenUri(Uri uri) {
  final Uri origin = _issuerOrigin(uri);
  return Uri(
    scheme: origin.scheme,
    host: origin.host,
    port: _normalizedPort(origin),
    path: demoTokenIssuerTokenPath,
  );
}

Uri _issuerOrigin(Uri uri) {
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: _normalizedPort(uri),
  );
}

int? _normalizedPort(Uri uri) {
  return uri.hasPort ? uri.port : null;
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
