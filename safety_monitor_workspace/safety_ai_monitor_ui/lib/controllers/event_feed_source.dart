import 'package:flutter/foundation.dart';

import '../models/event_log_item.dart';

abstract class EventFeedSource extends ChangeNotifier {
  List<EventLogItem> get logItems;
  Set<String> get selectedKeys;
  String get errorText;
  bool get isLoading;
  DateTime? get lastUpdatedAt;

  List<EventLogItem> getLogItemsForFrame(int frameValue);
  void selectLogItem(EventLogItem item);
  void clearSelection();
}
