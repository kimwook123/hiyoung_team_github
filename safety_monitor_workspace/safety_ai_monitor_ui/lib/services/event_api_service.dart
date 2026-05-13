import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api_event_item.dart';

class EventApiService {
  EventApiService({
    http.Client? client,
    this.baseUrl = 'http://127.0.0.1:8000',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<List<ApiEventItem>> fetchEvents({
    bool latestOnly = false,
    int? limit,
    String? eventType,
    String? status,
  }) async {
    final uri = _buildUri(
      '/api/events',
      {
        'latest_only': latestOnly ? 'true' : null,
        'limit': limit?.toString(),
        'event_type': _normalizeQueryValue(eventType),
        'status': _normalizeQueryValue(status),
      },
    );

    return _fetchEventList(uri);
  }

  Future<List<ApiEventItem>> fetchLatestEvents({
    int? limit,
    String? eventType,
    String? status,
  }) async {
    final uri = _buildUri(
      '/api/events/latest',
      {
        'limit': limit?.toString(),
        'event_type': _normalizeQueryValue(eventType),
        'status': _normalizeQueryValue(status),
      },
    );

    return _fetchEventList(uri);
  }

  Future<ApiEventItem?> fetchEventDetail(String eventKey) async {
    final normalizedEventKey = eventKey.trim();
    if (normalizedEventKey.isEmpty) {
      return null;
    }

    final uri = _buildUri(
      '/api/events/detail',
      {
        'event_key': normalizedEventKey,
        'latest_only': 'true',
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

  Future<List<ApiEventItem>> _fetchEventList(Uri uri) async {
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
