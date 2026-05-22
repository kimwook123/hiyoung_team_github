import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/api_event_item.dart';
import '../models/api_server_health.dart';
import '../models/frame_detection_snapshot.dart';
import '../models/source_item.dart';
import '../models/source_runtime_status.dart';

// 이 파일은 Flutter에서 FastAPI 서버를 호출하는 HTTP 서비스입니다.
// GET은 서버에서 데이터를 가져오는 요청이며, 여기서는 이벤트 목록/상세/health 조회에 사용합니다.

class EventApiService {
  // API 서버 기본 주소를 기준으로 이벤트와 health 요청을 보냅니다.
  EventApiService({
    http.Client? client,
    String baseUrl = 'http://127.0.0.1:8000',
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  final http.Client _client;
  String baseUrl;

  void updateBaseUrl(String nextBaseUrl) {
    final normalized = nextBaseUrl.trim();
    if (normalized.isEmpty) {
      return;
    }
    baseUrl = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  Uri buildRealtimeUpdatesUri() {
    final baseUri = Uri.parse(baseUrl);
    final nextScheme = baseUri.scheme.toLowerCase() == 'https' ? 'wss' : 'ws';
    return baseUri.replace(
      scheme: nextScheme,
      path: '/ws/updates',
      queryParameters: const {},
    );
  }

  Future<List<ApiEventItem>> fetchEvents({
    bool latestOnly = false,
    int? limit,
    String? eventType,
    String? status,
    String? sourceKey,
    String? sourceType,
    String? clientId,
    String? sessionId,
  }) async {
    // /api/events는 전체 기록 또는 최신 상태 목록을 가져오는 기본 조회 API입니다.
    final uri = _buildUri(
      '/api/events',
      {
        'latest_only': latestOnly ? 'true' : null,
        'limit': limit?.toString(),
        'event_type': _normalizeQueryValue(eventType),
        'status': _normalizeQueryValue(status),
        'source_key': _normalizeQueryValue(sourceKey),
        'source_type': _normalizeQueryValue(sourceType),
        'client_id': _normalizeQueryValue(clientId),
        'session_id': _normalizeQueryValue(sessionId),
      },
    );

    return _fetchEventList(uri);
  }

  Future<List<ApiEventItem>> fetchLatestEvents({
    int? limit,
    String? eventType,
    String? status,
    String? sourceKey,
    String? sourceType,
    String? clientId,
    String? sessionId,
  }) async {
    final uri = _buildUri(
      '/api/events/latest',
      {
        'limit': limit?.toString(),
        'event_type': _normalizeQueryValue(eventType),
        'status': _normalizeQueryValue(status),
        'source_key': _normalizeQueryValue(sourceKey),
        'source_type': _normalizeQueryValue(sourceType),
        'client_id': _normalizeQueryValue(clientId),
        'session_id': _normalizeQueryValue(sessionId),
      },
    );

    return _fetchEventList(uri);
  }

  Future<ApiEventItem?> fetchEventDetail(String eventKey, {String? sourceKey}) async {
    // 상세 패널은 목록과 별도로 /api/events/detail을 다시 호출해 최신 1건을 가져옵니다.
    final normalizedEventKey = eventKey.trim();
    if (normalizedEventKey.isEmpty) {
      return null;
    }

    final uri = _buildUri(
      '/api/events/detail',
      {
        'event_key': normalizedEventKey,
        'latest_only': 'true',
        'source_key': _normalizeQueryValue(sourceKey),
      },
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final item = decoded['item'];
      if (item is Map<String, dynamic>) {
        return ApiEventItem.fromJson(item);
      }
      if (item is Map) {
        return ApiEventItem.fromJson(Map<String, dynamic>.from(item));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<ApiServerHealth?> fetchHealth() async {
    // health check는 서버가 켜져 있는지와 event 저장소 경로를 확인하는 용도입니다.
    final uri = _buildUri('/health', const {});

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return ApiServerHealth.fromJson(decoded);
      }
      if (decoded is Map) {
        return ApiServerHealth.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<bool> resetServerData({
    required String sourceKey,
    required String sourceSlug,
  }) async {
    final uri = _buildUri('/api/admin/reset-data', const {});

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source_key': sourceKey,
          'source_slug': sourceSlug,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<SourceItem?> registerSource({
    required String sourceType,
    required String sourceValue,
    String clientId = '',
    String sessionId = '',
    bool resetExisting = true,
    bool startImmediately = true,
  }) async {
    final uri = _buildUri('/api/sources', const {});
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source_type': sourceType,
          'source_value': sourceValue,
          'client_id': clientId,
          'session_id': sessionId,
          'reset_existing': resetExisting,
          'start_immediately': startImmediately,
        }),
      );
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final item = decoded['item'];
      if (item is Map<String, dynamic>) {
        return SourceItem.fromJson(item);
      }
      if (item is Map) {
        return SourceItem.fromJson(Map<String, dynamic>.from(item));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<SourceItem?> uploadVideoSource({
    required String filePath,
    String clientId = '',
    String sessionId = '',
    bool resetExisting = true,
    bool startImmediately = true,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final baseUri = Uri.parse(baseUrl);
    final request = http.MultipartRequest(
      'POST',
      baseUri.replace(path: '/api/sources/upload'),
    );
    request.fields['client_id'] = clientId;
    request.fields['session_id'] = sessionId;
    request.fields['reset_existing'] = resetExisting ? 'true' : 'false';
    request.fields['start_immediately'] = startImmediately ? 'true' : 'false';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      final streamed = await request.send();
      if (streamed.statusCode != 200) {
        return null;
      }
      final response = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final item = decoded['item'];
      if (item is Map<String, dynamic>) {
        return SourceItem.fromJson(item);
      }
      if (item is Map) {
        return SourceItem.fromJson(Map<String, dynamic>.from(item));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<List<SourceItem>> fetchSources() async {
    final uri = _buildUri('/api/sources', const {});
    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }
      final items = decoded['items'];
      if (items is! List) {
        return const [];
      }
      return items
          .whereType<Map>()
          .map((item) => SourceItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> deleteSource(String sourceKey, {bool clearData = false}) async {
    final uri = _buildUri(
      '/api/sources/${Uri.encodeComponent(sourceKey)}',
      {
        'clear_data': clearData ? 'true' : 'false',
      },
    );
    try {
      final response = await _client.delete(uri);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<FrameDetectionSnapshot?> fetchCurrentFrameDetection({
    required String sourceKey,
    required double sourceTimeSeconds,
    double toleranceSeconds = 0.12,
  }) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty) {
      return null;
    }

    final uri = _buildUri(
      '/api/frame-detections/current',
      {
        'source_key': normalizedSourceKey,
        'source_time_seconds': sourceTimeSeconds.toString(),
        'tolerance_seconds': toleranceSeconds.toString(),
      },
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      if (decoded['found'] != true) {
        return null;
      }

      final item = decoded['item'];
      if (item is Map<String, dynamic>) {
        return FrameDetectionSnapshot.fromJson(item);
      }
      if (item is Map) {
        return FrameDetectionSnapshot.fromJson(Map<String, dynamic>.from(item));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<FrameDetectionSnapshot?> fetchLatestFrameDetection({
    required String sourceKey,
  }) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty) {
      return null;
    }

    final uri = _buildUri(
      '/api/frame-detections/latest',
      {
        'source_key': normalizedSourceKey,
      },
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      if (decoded['found'] != true) {
        return null;
      }

      final item = decoded['item'];
      if (item is Map<String, dynamic>) {
        return FrameDetectionSnapshot.fromJson(item);
      }
      if (item is Map) {
        return FrameDetectionSnapshot.fromJson(Map<String, dynamic>.from(item));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<List<SourceRuntimeStatus>> fetchSourceStatuses() async {
    final uri = _buildUri('/api/source-status', const {});

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }

      final items = decoded['items'];
      if (items is! List) {
        return const [];
      }

      return items
          .whereType<Map>()
          .map((item) => SourceRuntimeStatus.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ApiEventItem>> _fetchEventList(Uri uri) async {
    // 네트워크 실패나 JSON 파싱 실패가 나도 앱이 바로 죽지 않게 빈 목록으로 처리합니다.
    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }

      final items = decoded['items'];
      if (items is! List) {
        return const [];
      }

      return items
          .map(_toApiEventItemOrNull)
          .whereType<ApiEventItem>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  ApiEventItem? _toApiEventItemOrNull(Object? value) {
    try {
      if (value is Map<String, dynamic>) {
        return ApiEventItem.fromJson(value);
      }
      if (value is Map) {
        return ApiEventItem.fromJson(Map<String, dynamic>.from(value));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Uri _buildUri(String path, Map<String, String?> queryParameters) {
    final baseUri = Uri.parse(baseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return baseUri.replace(
      path: normalizedPath,
      queryParameters: {
        for (final entry in queryParameters.entries)
          if (entry.value != null) entry.key: entry.value!,
      },
    );
  }

  String? _normalizeQueryValue(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

}
