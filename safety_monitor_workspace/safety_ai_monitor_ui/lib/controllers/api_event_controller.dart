import 'package:flutter/foundation.dart';

import '../models/api_event_item.dart';
import '../services/event_api_service.dart';

class ApiEventController extends ChangeNotifier {
  ApiEventController({EventApiService? service})
      : _service = service ?? EventApiService();

  final EventApiService _service;

  List<ApiEventItem> items = const [];
  bool isLoading = false;
  String? errorMessage;
  DateTime? lastUpdatedAt;

  Future<void> loadLatestEvents({
    int? limit,
    String? eventType,
    String? status,
  }) async {
    await loadEvents(
      latestOnly: true,
      limit: limit,
      eventType: eventType,
      status: status,
    );
  }

  Future<void> loadEvents({
    bool latestOnly = false,
    int? limit,
    String? eventType,
    String? status,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final nextItems = await _service.fetchEvents(
        latestOnly: latestOnly,
        limit: limit,
        eventType: eventType,
        status: status,
      );
      items = nextItems;
      lastUpdatedAt = DateTime.now();
    } catch (error) {
      errorMessage = 'Failed to load API events: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ApiEventItem?> loadEventDetail(String eventKey) async {
    final normalizedEventKey = eventKey.trim();
    if (normalizedEventKey.isEmpty) {
      errorMessage = 'eventKey is required.';
      notifyListeners();
      return null;
    }

    try {
      errorMessage = null;
      final item = await _service.fetchEventDetail(normalizedEventKey);
      if (item == null) {
        errorMessage = 'Failed to load API event detail.';
      }
      notifyListeners();
      return item;
    } catch (error) {
      errorMessage = 'Failed to load API event detail: $error';
      notifyListeners();
      return null;
    }
  }

  void clear() {
    items = const [];
    errorMessage = null;
    lastUpdatedAt = null;
    notifyListeners();
  }
}
