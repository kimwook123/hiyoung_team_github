import 'package:flutter/foundation.dart';

import '../models/api_event_item.dart';
import '../services/local_event_json_service.dart';

// 파일 로그 모드에서 로컬 events.jsonl을 읽어 오버레이용 구조화 이벤트를 유지합니다.
class LocalEventJsonController extends ChangeNotifier {
  LocalEventJsonController({LocalEventJsonService? service})
      : _service = service ?? LocalEventJsonService();

  final LocalEventJsonService _service;

  String logPath = '';
  String errorText = '';
  List<ApiEventItem> items = const [];

  Future<void> loadLog(String path) async {
    logPath = path;
    errorText = '';

    if (path.isEmpty) {
      items = const [];
      notifyListeners();
      return;
    }

    try {
      items = await _service.readItems(path);
    } catch (error) {
      errorText = '구조화 이벤트 로그를 읽지 못했습니다: $error';
      items = const [];
    }

    _service.startWatch(
      path: path,
      onChanged: (nextItems) {
        if (_isSameItems(items, nextItems)) {
          return;
        }
        items = nextItems;
        notifyListeners();
      },
    );
    notifyListeners();
  }

  List<ApiEventItem> getItemsForTime(double secondsValue) {
    final selectedMap = <String, ApiEventItem>{};
    for (final item in items) {
      final eventKey = item.eventKey.trim();
      if (eventKey.isEmpty) {
        continue;
      }

      if (item.sourceTimeSeconds > secondsValue) {
        continue;
      }

      selectedMap[eventKey] = item;
    }

    return selectedMap.values
        .where((item) => _isActiveAtTime(item, secondsValue))
        .toList(growable: false);
  }

  void disposeController() {
    _service.stopWatch();
  }

  bool _isActiveAtTime(ApiEventItem item, double secondsValue) {
    if (item.sourceTimeSeconds.isNaN) {
      return false;
    }

    final normalizedStatus = item.status.trim().toUpperCase();
    if (normalizedStatus == 'END') {
      return false;
    }

    return secondsValue >= item.sourceTimeSeconds;
  }

  bool _isSameItems(List<ApiEventItem> left, List<ApiEventItem> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      final leftItem = left[index];
      final rightItem = right[index];
      if (leftItem.eventKey != rightItem.eventKey ||
          leftItem.frameId != rightItem.frameId ||
          leftItem.status != rightItem.status ||
          leftItem.sourceTimeSeconds != rightItem.sourceTimeSeconds ||
          leftItem.sourceTimeText != rightItem.sourceTimeText ||
          leftItem.relatedDetections.length != rightItem.relatedDetections.length) {
        return false;
      }
    }

    return true;
  }
}
