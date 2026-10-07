import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<ApiClientResponse> getJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await _httpClient
        .get(
          _buildUri(path),
          headers: _mergeHeaders(const {
            'Accept': 'application/json',
          }, headers),
        )
        .timeout(const Duration(seconds: 10));

    return ApiClientResponse(
      statusCode: response.statusCode,
      data: _decodeBody(response.body),
    );
  }

  Future<ApiClientResponse> postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final response = await _httpClient
        .post(
          _buildUri(path),
          headers: _mergeHeaders(const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          }, headers),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    return ApiClientResponse(
      statusCode: response.statusCode,
      data: _decodeBody(response.body),
    );
  }

  Future<ApiClientResponse> putJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final response = await _httpClient
        .put(
          _buildUri(path),
          headers: _mergeHeaders(const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          }, headers),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    return ApiClientResponse(
      statusCode: response.statusCode,
      data: _decodeBody(response.body),
    );
  }

  Future<ApiClientResponse> patchJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final response = await _httpClient
        .patch(
          _buildUri(path),
          headers: _mergeHeaders(const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          }, headers),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    return ApiClientResponse(
      statusCode: response.statusCode,
      data: _decodeBody(response.body),
    );
  }

  Future<ApiClientResponse> deleteJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await _httpClient
        .delete(
          _buildUri(path),
          headers: _mergeHeaders(const {
            'Accept': 'application/json',
          }, headers),
        )
        .timeout(const Duration(seconds: 10));

    return ApiClientResponse(
      statusCode: response.statusCode,
      data: _decodeBody(response.body),
    );
  }

  Future<ApiClientResponse> postMultipart(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    required String contentType,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    final request = http.MultipartRequest('POST', uri);

    if (headers != null) {
      request.headers.addAll(headers);
    }
    request.headers['Accept'] = 'application/json';

    final mediaType = MediaType.parse(contentType);
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: mediaType,
      ),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    return ApiClientResponse(
      statusCode: response.statusCode,
      data: _decodeBody(response.body),
    );
  }

  Uri _buildUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }

    return Uri.parse('$baseUrl$path');
  }

  Map<String, String> _mergeHeaders(
    Map<String, String> baseHeaders,
    Map<String, String>? additionalHeaders,
  ) {
    if (additionalHeaders == null || additionalHeaders.isEmpty) {
      return baseHeaders;
    }

    return <String, String>{
      ...baseHeaders,
      ...additionalHeaders,
    };
  }

  static Object? _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }
}

class ApiClientResponse {
  const ApiClientResponse({
    required this.statusCode,
    required this.data,
  });

  final int statusCode;
  final Object? data;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic>? get jsonBody {
    if (data is Map<String, dynamic>) {
      return data as Map<String, dynamic>;
    }

    return null;
  }

  List<dynamic>? get jsonListBody {
    if (data is List<dynamic>) {
      return data as List<dynamic>;
    }

    return null;
  }
}
