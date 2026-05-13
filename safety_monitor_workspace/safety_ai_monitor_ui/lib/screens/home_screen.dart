import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/api_event_controller.dart';
import '../controllers/api_event_feed_source.dart';
import '../controllers/event_feed_source.dart';
import '../controllers/event_log_controller.dart';
import '../controllers/file_event_feed_source.dart';
import '../controllers/video_panel_controller.dart';
import '../models/api_event_item.dart';
import '../models/event_log_item.dart';
import '../services/app_link_service.dart';
import '../widgets/event_log_box.dart';
import '../widgets/file_bar.dart';
import '../widgets/video_control_bar.dart';
import '../widgets/video_view_box.dart';

enum EventSourceMode {
  fileLog,
  api,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final VideoPanelController videoController;
  late final EventLogController logController;
  late final FileEventFeedSource fileEventFeed;
  late final ApiEventController apiEventController;
  late final ApiEventFeedSource apiEventFeed;
  late final AppLinkService appLinkService;
  final TextEditingController streamTextController = TextEditingController();
  EventSourceMode eventSourceMode = EventSourceMode.fileLog;
  ApiEventItem? selectedApiEventDetail;
  bool isLoadingApiDetail = false;
  String? apiDetailErrorMessage;

  EventFeedSource get activeEventFeed {
    switch (eventSourceMode) {
      case EventSourceMode.fileLog:
        return fileEventFeed;
      case EventSourceMode.api:
        return apiEventFeed;
    }
  }

  @override
  void initState() {
    super.initState();
    videoController = VideoPanelController();
    logController = EventLogController();
    fileEventFeed = FileEventFeedSource(logController);
    apiEventController = ApiEventController();
    apiEventFeed = ApiEventFeedSource(apiEventController);
    appLinkService = AppLinkService();

    // GUI가 열릴 때 이전 선택 상태는 비운다
    appLinkService.clearSourceState();
  }

  @override
  void dispose() {
    videoController.disposeController();
    fileEventFeed.dispose();
    apiEventFeed.dispose();
    logController.disposeController();
    streamTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety AI Monitor UI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FileBar(
              videoPath: videoController.videoPath,
              sourceType: videoController.sourceType,
              logPath: logController.logPath,
              isReplayMode: videoController.isReplayMode,
              streamTextController: streamTextController,
              onPickVideo: _pickVideoFile,
              onOpenStream: _openStream,
              onReturnLive: _returnToLive,
            ),
            const SizedBox(height: 16),
            _buildEventSourceControls(),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedBuilder(
                            animation: Listenable.merge(
                              [videoController, fileEventFeed, apiEventFeed],
                            ),
                            builder: (context, _) {
                              return VideoViewBox(
                                controller: videoController,
                                overlayItems: _getOverlayItems(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: videoController,
                          builder: (context, _) {
                            return VideoControlBar(controller: videoController);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildApiDetailPanel(),
                        if (eventSourceMode == EventSourceMode.api)
                          const SizedBox(height: 12),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: Listenable.merge(
                              [fileEventFeed, apiEventFeed],
                            ),
                            builder: (context, _) {
                              return EventLogBox(
                                eventFeed: activeEventFeed,
                                onTapItem: _onTapEventItem,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventSourceControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SegmentedButton<EventSourceMode>(
                segments: const [
                  ButtonSegment(
                    value: EventSourceMode.fileLog,
                    label: Text('파일 로그'),
                  ),
                  ButtonSegment(
                    value: EventSourceMode.api,
                    label: Text('API 서버'),
                  ),
                ],
                selected: {eventSourceMode},
                onSelectionChanged: (selection) {
                  final nextMode = selection.first;
                  if (nextMode == eventSourceMode) {
                    return;
                  }
                  setState(() {
                    eventSourceMode = nextMode;
                    selectedApiEventDetail = null;
                    apiDetailErrorMessage = null;
                    isLoadingApiDetail = false;
                  });
                  activeEventFeed.clearSelection();
                },
              ),
              const Spacer(),
              if (eventSourceMode == EventSourceMode.api)
                FilledButton(
                  onPressed: _refreshApiEvents,
                  child: const Text('API 새로고침'),
                ),
            ],
          ),
          if (eventSourceMode == EventSourceMode.api) ...[
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: apiEventFeed,
              builder: (context, _) {
                return _buildApiStatusText();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApiStatusText() {
    String text = 'API 모드가 선택되었습니다. "API 새로고침"으로 이벤트를 가져옵니다.';

    if (apiEventController.isLoading) {
      text = 'API 이벤트 불러오는 중...';
    } else if ((apiEventController.errorMessage ?? '').isNotEmpty) {
      text = apiEventController.errorMessage!;
    } else if (apiEventController.lastUpdatedAt != null) {
      final updatedAt = apiEventController.lastUpdatedAt!;
      final timestamp =
          '${updatedAt.year.toString().padLeft(4, '0')}-'
          '${updatedAt.month.toString().padLeft(2, '0')}-'
          '${updatedAt.day.toString().padLeft(2, '0')} '
          '${updatedAt.hour.toString().padLeft(2, '0')}:'
          '${updatedAt.minute.toString().padLeft(2, '0')}:'
          '${updatedAt.second.toString().padLeft(2, '0')}';
      text = '마지막 갱신: $timestamp';
    }

    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.black54,
      ),
    );
  }

  Widget _buildApiDetailPanel() {
    if (eventSourceMode != EventSourceMode.api) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API 이벤트 상세',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (isLoadingApiDetail)
            const Text('상세 정보 불러오는 중...')
          else if ((apiDetailErrorMessage ?? '').isNotEmpty)
            Text(apiDetailErrorMessage!)
          else if (selectedApiEventDetail == null)
            const Text('이벤트를 선택하면 상세 정보가 표시됩니다.')
          else
            _buildApiDetailContent(selectedApiEventDetail!),
        ],
      ),
    );
  }

  Widget _buildApiDetailContent(ApiEventItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailLine('eventKey', item.eventKey),
        _buildDetailLine('eventType', item.eventType),
        _buildDetailLine('status', item.status),
        _buildDetailLine('level', item.level),
        _buildDetailLine('message', item.message),
        _buildDetailLine('frameId', item.frameId.toString()),
        _buildDetailLine('personId', item.personId?.toString() ?? 'unknown'),
        _buildDetailLine(
          'durationSeconds',
          item.durationSeconds.toStringAsFixed(1),
        ),
        _buildDetailLine('sourceTimeText', item.sourceTimeText),
        _buildDetailLine(
          'clipPath',
          item.clipPath.isEmpty ? '-' : item.clipPath,
        ),
        _buildDetailLine(
          'relatedDetections',
          item.relatedDetections.length.toString(),
        ),
      ],
    );
  }

  Widget _buildDetailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: ${value.isEmpty ? '-' : value}'),
    );
  }

  Future<void> _pickVideoFile() async {
    const group = XTypeGroup(
      label: 'video',
      extensions: ['mp4', 'mov', 'avi', 'mkv'],
    );

    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) {
      return;
    }

    await appLinkService.writeSourceState(
      sourceType: 'video',
      sourceValue: file.path,
    );
    await appLinkService.clearLogFile(
      sourceType: 'video',
      sourceValue: file.path,
    );
    await _watchExpectedLog(
      sourceType: 'video',
      sourceValue: file.path,
    );
    await videoController.openVideo(file.path);
  }

  Future<void> _openStream() async {
    final streamUrl = streamTextController.text.trim();
    if (streamUrl.isEmpty) {
      return;
    }

    await appLinkService.writeSourceState(
      sourceType: 'stream',
      sourceValue: streamUrl,
    );
    await appLinkService.clearLogFile(
      sourceType: 'stream',
      sourceValue: streamUrl,
    );
    await _watchExpectedLog(
      sourceType: 'stream',
      sourceValue: streamUrl,
    );
    await videoController.openVideo(
      streamUrl,
      nextSourceType: 'stream',
    );
  }

  List<EventLogItem> _getOverlayItems() {
    return activeEventFeed.getLogItemsForFrame(videoController.currentFrameValue);
  }

  Future<void> _onTapEventItem(EventLogItem item) async {
    activeEventFeed.selectLogItem(item);

    if (eventSourceMode == EventSourceMode.api) {
      final eventKey = item.eventKeyText.trim();
      if (eventKey.isNotEmpty && eventKey != '-') {
        setState(() {
          isLoadingApiDetail = true;
          apiDetailErrorMessage = null;
          selectedApiEventDetail = null;
        });

        try {
          final detail = await apiEventController.loadEventDetail(eventKey);
          setState(() {
            selectedApiEventDetail = detail;
            if (detail == null) {
              apiDetailErrorMessage = '상세 정보를 가져오지 못했습니다.';
            }
          });
        } finally {
          setState(() {
            isLoadingApiDetail = false;
          });
        }
      }
    }

    if (videoController.isStreamMode && item.hasClip) {
      await videoController.openReplayClip(item.clipPathText);
      return;
    }

    final targetFrame = item.startFrameValue ?? item.frameValue;
    if (targetFrame == null) {
      return;
    }

    final targetMs = ((targetFrame / videoController.frameRate) * 1000).round();
    final ratio = videoController.totalDuration.inMilliseconds <= 0
        ? 0.0
        : targetMs / videoController.totalDuration.inMilliseconds;
    await videoController.moveToRatio(
      ratio,
    );
  }

  Future<void> _returnToLive() async {
    await videoController.returnToLive();
  }

  Future<void> _refreshApiEvents() async {
    await apiEventController.loadLatestEvents(limit: 200);
  }

  Future<void> _watchExpectedLog({
    required String sourceType,
    required String sourceValue,
  }) async {
    final logPath = await appLinkService.buildLogPath(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );
    await logController.loadLog(logPath);
  }
}
