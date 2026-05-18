import 'package:flutter/foundation.dart';

import '../adapters/api_event_log_adapter.dart';
import '../models/api_event_item.dart';
import '../models/api_server_health.dart';
import '../models/event_log_item.dart';
import '../services/event_api_service.dart';

// FastAPI 서버에서 이벤트와 health 정보를 가져와 API 모드 상태를 관리하는 controller입니다.
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

  // 화면 위젯은 기존 EventLogItem을 기대하므로 API 응답을 어댑터로 변환해서 노출합니다.
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
    // GET /api/events 또는 latest_only=true 조회를 담당합니다.
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
    // 선택한 이벤트 한 건의 상세 정보를 GET /api/events/detail로 조회합니다.
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
    // GET /health로 서버 상태와 events.jsonl 존재 여부를 확인합니다.
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
    // API 목록도 기존 오버레이 위젯을 재사용할 수 있게 frame 기준으로 다시 걸러냅니다.
    final selectedMap = <String, EventLogItem>{};
    for (final item in logItems) {
      if (!item.matchesFrame(frameValue)) {
        continue;
      }
      selectedMap[item.eventKeyText] = item;
    }
    return selectedMap.values.toList();
  }

  List<ApiEventItem> getItemsForFrame(int frameValue) {
    final selectedMap = <String, ApiEventItem>{};
    for (final item in items) {
      if (!_matchesFrame(item, frameValue)) {
        continue;
      }
      selectedMap[item.eventKey] = item;
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

  bool _matchesFrame(ApiEventItem item, int frameValue) {
    final startFrame = item.startedFrameId;
    final endFrame = item.endedFrameId;
    if (startFrame == null) {
      return false;
    }

    if (endFrame != null) {
      return frameValue >= startFrame && frameValue <= endFrame;
    }

    return item.frameId == frameValue || frameValue >= startFrame;
  }
}
