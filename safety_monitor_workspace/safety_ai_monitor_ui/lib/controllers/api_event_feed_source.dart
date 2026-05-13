import '../models/event_log_item.dart';
import 'api_event_controller.dart';
import 'event_feed_source.dart';

class ApiEventFeedSource extends EventFeedSource {
  ApiEventFeedSource(this.controller) {
    controller.addListener(_handleControllerChanged);
  }

  final ApiEventController controller;

  @override
  List<EventLogItem> get logItems => controller.logItems;

  @override
  Set<String> get selectedKeys => controller.selectedKeys;

  @override
  String get errorText => controller.errorMessage ?? '';

  @override
  bool get isLoading => controller.isLoading;

  @override
  DateTime? get lastUpdatedAt => controller.lastUpdatedAt;

  @override
  List<EventLogItem> getLogItemsForFrame(int frameValue) {
    return controller.getLogItemsForFrame(frameValue);
  }

  @override
  void selectLogItem(EventLogItem item) {
    controller.selectLogItem(item);
  }

  @override
  void clearSelection() {
    controller.clearSelection();
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    notifyListeners();
  }
}
