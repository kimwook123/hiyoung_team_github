import 'package:flutter/foundation.dart';

import '../adapters/api_event_log_adapter.dart';
import '../models/api_event_item.dart';
import '../models/api_server_health.dart';
import '../models/event_log_item.dart';
import '../services/event_api_service.dart';

class ApiEventController extends ChangeNotifier {
  ApiEventController({EventApiService? service})
      : _service = service ?? EventApiService();

  final EventApiService _service;

  List<ApiEventItem> items = const [];
  Set<String> selectedKeys = <String>{};
  bool isLoading = false;
  String? errorMessage;
  DateTime? lastUpdatedAt;
  ApiServerHealth? serverHealth;
  bool isCheckingHealth = false;
  String? healthErrorMessage;
  DateTime? lastHealthCheckedAt;

  List<EventLogItem> get logItems => apiEventsToLogItems(items);

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

  Future<void> checkHealth() async {
    isCheckingHealth = true;
    healthErrorMessage = null;
    notifyListeners();

    try {
      final nextHealth = await _service.fetchHealth();
      serverHealth = nextHealth;
      if (nextHealth == null) {
        healthErrorMessage = 'API 서버 상태를 확인할 수 없습니다.';
      }
      lastHealthCheckedAt = DateTime.now();
    } catch (_) {
      serverHealth = null;
      healthErrorMessage = 'API 서버 상태를 확인할 수 없습니다.';
      lastHealthCheckedAt = DateTime.now();
    } finally {
      isCheckingHealth = false;
      notifyListeners();
    }
  }

  List<EventLogItem> getLogItemsForFrame(int frameValue) {
    final selectedMap = <String, EventLogItem>{};
    for (final item in logItems) {
      if (!item.matchesFrame(frameValue)) {
        continue;
      }
      selectedMap[item.eventKeyText] = item;
    }
    return selectedMap.values.toList();
  }

  void selectLogItem(EventLogItem item) {
    selectedKeys = {item.eventKeyText};
    notifyListeners();
  }

  void clearSelection() {
    selectedKeys = <String>{};
    notifyListeners();
  }

  void clear() {
    items = const [];
    selectedKeys = <String>{};
    errorMessage = null;
    lastUpdatedAt = null;
    notifyListeners();
  }
}
