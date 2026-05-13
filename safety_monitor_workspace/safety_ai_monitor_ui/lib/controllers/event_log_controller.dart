import 'package:flutter/foundation.dart';

import '../models/event_log_item.dart';
import '../services/event_log_service.dart';

class EventLogController extends ChangeNotifier {
  EventLogController({EventLogService? service})
      : _service = service ?? EventLogService();

  final EventLogService _service;

  String logPath = '';
  String errorText = '';
  List<EventLogItem> items = const [];
  Set<String> selectedKeys = <String>{};

  Future<void> loadLog(String path) async {
    logPath = path;
    errorText = '';

    if (path.isEmpty) {
      items = const [];
      notifyListeners();
      return;
    }

    final nextItems = await _service.readItems(path);
    if (!_isSameItems(items, nextItems)) {
      items = nextItems;
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

  Future<void> loadLogIfExists(String path) async {
    if (path.isEmpty) {
      return;
    }
    await loadLog(path);
  }

  void disposeController() {
    _service.stopWatch();
  }

  List<EventLogItem> getItemsForFrame(int frameValue) {
    final selectedMap = <String, EventLogItem>{};
    for (final item in items) {
      if (!item.matchesFrame(frameValue)) {
        continue;
      }
      selectedMap[item.eventKeyText] = item;
    }
    return selectedMap.values.toList();
  }

  void selectItem(EventLogItem item) {
    selectedKeys = {item.eventKeyText};
    notifyListeners();
  }

  void clearSelection() {
    selectedKeys = <String>{};
    notifyListeners();
  }

  bool _isSameItems(List<EventLogItem> left, List<EventLogItem> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index].rawText != right[index].rawText) {
        return false;
      }
    }
    return true;
  }
}
