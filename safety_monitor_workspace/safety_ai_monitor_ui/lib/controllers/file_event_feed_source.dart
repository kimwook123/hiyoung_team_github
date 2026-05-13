import '../models/event_log_item.dart';
import 'event_feed_source.dart';
import 'event_log_controller.dart';

// 기존 txt 로그 기반 EventLogController를 공통 EventFeedSource 형태로 감싸는 어댑터입니다.
class FileEventFeedSource extends EventFeedSource {
  FileEventFeedSource(this.controller) {
    controller.addListener(_handleControllerChanged);
  }

  final EventLogController controller;

  @override
  List<EventLogItem> get logItems => controller.items;

  @override
  Set<String> get selectedKeys => controller.selectedKeys;

  @override
  String get errorText => controller.errorText;

  @override
  bool get isLoading => false;

  @override
  DateTime? get lastUpdatedAt => null;

  @override
  List<EventLogItem> getLogItemsForFrame(int frameValue) {
    return controller.getItemsForFrame(frameValue);
  }

  @override
  void selectLogItem(EventLogItem item) {
    controller.selectItem(item);
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
    // 내부 controller 변경을 다시 전달해서 UI가 이 어댑터만 구독해도 갱신되게 합니다.
    notifyListeners();
  }
}
