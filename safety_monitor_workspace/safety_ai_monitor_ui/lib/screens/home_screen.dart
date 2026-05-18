import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/api_event_controller.dart';
import '../controllers/api_event_feed_source.dart';
import '../controllers/event_feed_source.dart';
import '../controllers/event_log_controller.dart';
import '../controllers/file_event_feed_source.dart';
import '../controllers/local_event_json_controller.dart';
import '../controllers/video_panel_controller.dart';
import '../models/api_event_item.dart';
import '../models/event_log_item.dart';
import '../models/video_overlay_detection.dart';
import '../services/app_link_service.dart';
import '../widgets/event_log_box.dart';
import '../widgets/file_bar.dart';
import '../widgets/video_control_bar.dart';
import '../widgets/video_view_box.dart';

// 메인 화면입니다.
// 파일 로그 모드와 API 서버 모드를 모두 품고 있으며, 실제 화면 조합은 여기서 결정합니다.
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
  static const String _apiServerBaseUrl = 'http://127.0.0.1:8000';
  static const Duration _apiAutoRefreshInterval = Duration(seconds: 3);
  late final VideoPanelController videoController;
  late final EventLogController logController;
  late final FileEventFeedSource fileEventFeed;
  late final LocalEventJsonController localEventJsonController;
  late final ApiEventController apiEventController;
  late final ApiEventFeedSource apiEventFeed;
  late final AppLinkService appLinkService;
  final ScrollController pageScrollController = ScrollController();
  final ScrollController rightPanelScrollController = ScrollController();
  final TextEditingController streamTextController = TextEditingController();
  EventSourceMode eventSourceMode = EventSourceMode.fileLog;
  ApiEventItem? selectedApiEventDetail;
  bool isLoadingApiDetail = false;
  String? apiDetailErrorMessage;
  Timer? apiAutoRefreshTimer;

  EventFeedSource get activeEventFeed {
    // 화면 위젯은 이 getter만 보면 현재 어떤 모드인지 몰라도 같은 방식으로 동작합니다.
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
    localEventJsonController = LocalEventJsonController();
    apiEventController = ApiEventController();
    apiEventFeed = ApiEventFeedSource(apiEventController);
    appLinkService = AppLinkService();

    // GUI가 열릴 때 이전 선택 상태는 비운다
    appLinkService.clearSourceState();
  }

  @override
  void dispose() {
    apiAutoRefreshTimer?.cancel();
    videoController.disposeController();
    fileEventFeed.dispose();
    localEventJsonController.disposeController();
    apiEventFeed.dispose();
    logController.disposeController();
    pageScrollController.dispose();
    rightPanelScrollController.dispose();
    streamTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety AI Monitor UI'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentAreaHeight = math.max(
            720.0,
            constraints.maxHeight - 180.0,
          );

          return Scrollbar(
            controller: pageScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: pageScrollController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 상단 입력 영역은 기존 파일 기반 흐름을 그대로 유지합니다.
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
                    SizedBox(
                      height: contentAreaHeight,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                Expanded(
                                  child: AnimatedBuilder(
                                        animation: Listenable.merge(
                                          [
                                            videoController,
                                            fileEventFeed,
                                            localEventJsonController,
                                            apiEventFeed,
                                          ],
                                        ),
                                        builder: (context, _) {
                                          // 오버레이는 현재 활성 feed에서 프레임 기준 이벤트만 받아 재사용합니다.
                                          return VideoViewBox(
                                            controller: videoController,
                                            overlayItems: _getOverlayItems(),
                                            overlayDetections: _getOverlayDetections(),
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Column(
                                  children: [
                                    if (eventSourceMode == EventSourceMode.api)
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: Scrollbar(
                                          controller: rightPanelScrollController,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            controller: rightPanelScrollController,
                                            child: Column(
                                              children: [
                                                _buildApiServerHealthPanel(),
                                                const SizedBox(height: 12),
                                                _buildApiDetailPanel(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventSourceControls() {
    // 사용자가 파일 로그 모드와 API 서버 모드를 전환하는 최소 제어 영역입니다.
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
                  _changeEventSourceMode(selection.first);
                },
              ),
              const Spacer(),
              if (eventSourceMode == EventSourceMode.api)
                FilledButton(
                  // 자동 polling이 있어도, 사용자가 즉시 다시 받고 싶을 때 수동 갱신할 수 있게 둡니다.
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
    String text =
        'API 모드가 선택되었습니다. 3초마다 자동 새로고침되며 "API 새로고침"으로 수동 갱신도 가능합니다.';

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

    // API 모드에서만 보이는 상세 패널입니다.
    // 이벤트 목록 클릭 후 GET /api/events/detail 결과를 요약해서 보여 줍니다.
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

  Widget _buildApiServerHealthPanel() {
    if (eventSourceMode != EventSourceMode.api) {
      return const SizedBox.shrink();
    }

    // /health 호출 결과를 보여 주는 보조 패널입니다.
    // 서버가 꺼졌는지, events.jsonl을 찾았는지 빠르게 점검할 때 사용합니다.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedBuilder(
        animation: apiEventFeed,
        builder: (context, _) {
          final health = apiEventController.serverHealth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'API 서버 상태',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: apiEventController.isCheckingHealth
                        ? null
                        : _checkApiHealth,
                    child: const Text('상태 확인'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (apiEventController.isCheckingHealth)
                const Text('확인 중...')
              else ...[
                if ((apiEventController.healthErrorMessage ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(apiEventController.healthErrorMessage!),
                  ),
                if (health != null) ...[
                  _buildDetailLine('status', health.status),
                  _buildDetailLine(
                    'eventLogExists',
                    health.eventLogExists ? 'true' : 'false',
                  ),
                  _buildDetailLine('eventLogPath', health.eventLogPath),
                  _buildDetailLine(
                    'lastHealthCheckedAt',
                    _formatDateTime(apiEventController.lastHealthCheckedAt),
                  ),
                ] else
                  Text(
                    'API 모드 진입 시 서버 상태를 자동 확인합니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildApiDetailContent(ApiEventItem item) {
    // clipUrl 우선, clipPath fallback 정책과 서버 정규화 clip 필드를 여기서 눈으로 확인할 수 있습니다.
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
          'clipAvailable',
          item.clipAvailable ? 'true' : 'false',
        ),
        _buildDetailLine(
          'preferredClipSource',
          item.preferredClipSource.isEmpty ? '-' : item.preferredClipSource,
        ),
        _buildDetailLine(
          'clipUploadOk',
          item.clipUploadOk ? 'true' : 'false',
        ),
        _buildDetailLine('clipUrl', item.clipUrl.isEmpty ? '-' : item.clipUrl),
        _buildDetailLine(
          'serverClipName',
          item.serverClipName.isEmpty ? '-' : item.serverClipName,
        ),
        _buildDetailLine(
          'serverClipPath',
          item.serverClipPath.isEmpty ? '-' : item.serverClipPath,
        ),
        _buildDetailLine('clipPolicy', _describeClipPolicy(item)),
        _buildDetailLine(
          'relatedDetections',
          item.relatedDetections.length.toString(),
        ),
        _buildRelatedDetections(item),
        if (_resolveApiClipSource(item).isNotEmpty) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _openApiDetailClip(item),
            child: const Text('클립 열기'),
          ),
        ],
      ],
    );
  }

  Widget _buildRelatedDetections(ApiEventItem detail) {
    if (detail.relatedDetections.isEmpty) {
      return const SizedBox.shrink();
    }

    // 탐지 근거는 너무 길어지지 않도록 일부만 보여 줍니다.
    final visibleDetections = detail.relatedDetections.take(5).toList();
    final remainingCount = detail.relatedDetections.length - visibleDetections.length;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '관련 탐지 객체',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          for (final detection in visibleDetections) ...[
            Text(_formatDetectionSummary(detection)),
            Text(
              _formatDetectionBoxLine(detection),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (remainingCount > 0)
            Text(
              '외 $remainingCount개',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: ${value.isEmpty ? '-' : value}'),
    );
  }

  String _formatDetectionSummary(Map<String, dynamic> detection) {
    final name = (detection['name']?.toString().trim().isNotEmpty ?? false)
        ? detection['name'].toString().trim()
        : 'unknown';
    final score = _formatScore(detection['score']);
    final trackId = detection['track_id']?.toString().trim();
    final trackIdText = (trackId?.isNotEmpty ?? false) ? trackId! : '-';
    return '$name / score=$score / id=$trackIdText';
  }

  String _formatDetectionBoxLine(Map<String, dynamic> detection) {
    return 'box=${_formatBox(detection['box'])}';
  }

  String _formatScore(Object? score) {
    if (score is num) {
      return score.toStringAsFixed(2);
    }

    if (score is String) {
      final parsed = double.tryParse(score);
      if (parsed != null) {
        return parsed.toStringAsFixed(2);
      }
    }

    return '-';
  }

  double? _toDoubleValue(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  String _buildDetectionLabel(
    ApiEventItem item,
    Map<String, dynamic> detection,
  ) {
    final name = (detection['name']?.toString().trim().isNotEmpty ?? false)
        ? detection['name'].toString().trim()
        : item.eventType;
    final trackId = detection['track_id']?.toString().trim();
    if (trackId != null && trackId.isNotEmpty) {
      return '$name #$trackId';
    }
    return name;
  }

  Color _colorForLevel(String level) {
    switch (level.trim().toUpperCase()) {
      case 'DANGER':
        return Colors.redAccent;
      case 'WARNING':
        return Colors.orangeAccent;
      default:
        return Colors.lightBlueAccent;
    }
  }

  String _formatBox(Object? box) {
    if (box is! Map) {
      return '-';
    }

    final x1 = box['x1'];
    final y1 = box['y1'];
    final x2 = box['x2'];
    final y2 = box['y2'];
    if (x1 == null || y1 == null || x2 == null || y2 == null) {
      return '-';
    }

    return '($x1, $y1, $x2, $y2)';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
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

  List<VideoOverlayDetection> _getOverlayDetections() {
    final items = eventSourceMode == EventSourceMode.api
        ? apiEventController.getItemsForFrame(videoController.currentFrameValue)
        : localEventJsonController.getItemsForFrame(
            videoController.currentFrameValue,
          );
    if (items.isEmpty) {
      return const [];
    }

    final detections = <VideoOverlayDetection>[];
    final seenKeys = <String>{};
    for (final item in items) {
      for (final detection in item.relatedDetections) {
        final box = detection['box'];
        if (box is! Map) {
          continue;
        }

        final x1 = _toDoubleValue(box['x1']);
        final y1 = _toDoubleValue(box['y1']);
        final x2 = _toDoubleValue(box['x2']);
        final y2 = _toDoubleValue(box['y2']);
        if (x1 == null || y1 == null || x2 == null || y2 == null) {
          continue;
        }

        final key =
            '${item.eventKey}:${detection['track_id']}:${detection['name']}:$x1:$y1:$x2:$y2';
        if (!seenKeys.add(key)) {
          continue;
        }

        detections.add(
          VideoOverlayDetection(
            key: key,
            label: _buildDetectionLabel(item, detection),
            color: _colorForLevel(item.level),
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
          ),
        );
      }
    }

    return detections;
  }

  Future<void> _onTapEventItem(EventLogItem item) async {
    // 클릭 공통 동작:
    // 1) 선택 표시
    // 2) API 모드면 상세 조회
    // 3) 스트림 replay clip 또는 해당 프레임으로 이동
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

  Future<void> _openApiDetailClip(ApiEventItem item) async {
    // API 상세 패널의 "클립 열기"는 서버 clip_url을 우선 사용하고,
    // 없으면 기존 로컬 clipPath를 fallback으로 사용합니다.
    final resolvedPath = _resolveApiClipSource(item);
    if (resolvedPath.isEmpty) {
      setState(() {
        apiDetailErrorMessage = '클립 경로가 비어 있습니다.';
      });
      return;
    }

    try {
      await videoController.openReplayClip(resolvedPath);
    } catch (error) {
      setState(() {
        apiDetailErrorMessage = '클립을 열 수 없습니다: $error';
      });
    }
  }

  Future<void> _refreshApiEvents() async {
    await apiEventController.loadLatestEvents(limit: 200);
  }

  Future<void> _checkApiHealth() async {
    await apiEventController.checkHealth();
  }

  void _changeEventSourceMode(EventSourceMode nextMode) {
    if (nextMode == eventSourceMode) {
      return;
    }

    // 모드 전환 시 선택 상태와 상세 패널 상태를 정리하고,
    // API 모드 진입 시에는 health 확인과 자동 새로고침을 시작합니다.
    _stopApiAutoRefresh();
    fileEventFeed.clearSelection();
    apiEventFeed.clearSelection();

    setState(() {
      eventSourceMode = nextMode;
      selectedApiEventDetail = null;
      apiDetailErrorMessage = null;
      isLoadingApiDetail = false;
    });

    if (nextMode == EventSourceMode.api) {
      unawaited(apiEventController.checkHealth());
      unawaited(_refreshApiEventsIfNeeded());
      _startApiAutoRefresh();
    }
  }

  void _startApiAutoRefresh() {
    // 실시간 push(WebSocket) 대신 3초 간격 polling으로 서버 최신 이벤트를 가져옵니다.
    _stopApiAutoRefresh();
    apiAutoRefreshTimer = Timer.periodic(_apiAutoRefreshInterval, (_) {
      unawaited(_refreshApiEventsIfNeeded());
    });
  }

  void _stopApiAutoRefresh() {
    apiAutoRefreshTimer?.cancel();
    apiAutoRefreshTimer = null;
  }

  Future<void> _refreshApiEventsIfNeeded() async {
    if (!mounted || eventSourceMode != EventSourceMode.api) {
      return;
    }
    if (apiEventController.isLoading) {
      // 이미 요청 중이면 중복 호출을 피해서 화면 흔들림과 불필요한 서버 호출을 줄입니다.
      return;
    }
    await _refreshApiEvents();
  }

  String _resolveClipPath(String clipPath) {
    // 기존 로컬 clipPath는 Python 작업 디렉터리 기준 상대 경로일 수 있어
    // Flutter 쪽에서 한 번 더 보정해 줍니다.
    final trimmed = clipPath.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return '';
    }

    final normalized = trimmed.replaceAll('\\', '/');
    final isWindowsAbsolute = RegExp(r'^[A-Za-z]:[\\/]').hasMatch(trimmed);
    final isUnixAbsolute = normalized.startsWith('/');
    if (isWindowsAbsolute || isUnixAbsolute) {
      return trimmed;
    }

    if (normalized.startsWith('logs/')) {
      final workspaceRoot = Directory.current.parent.path;
      final relativePath = normalized.replaceAll('/', Platform.pathSeparator);
      final workspacePath =
          '$workspaceRoot${Platform.pathSeparator}safety_ai_monitor'
          '${Platform.pathSeparator}$relativePath';
      return workspacePath;
    }

    return trimmed;
  }

  String _resolveApiClipSource(ApiEventItem item) {
    // 서버가 clip_url을 돌려준 경우 그 URL을 우선 사용하고,
    // 아직 서버 클립이 없으면 기존 로컬 경로를 예비 경로로 사용합니다.
    final clipUrl = item.clipUrl.trim();
    if (clipUrl.isNotEmpty && clipUrl != '-') {
      return _resolveClipUrl(clipUrl);
    }
    return _resolveClipPath(item.clipPath);
  }

  String _describeClipPolicy(ApiEventItem item) {
    switch (item.preferredClipSource.trim()) {
      case 'server':
        return '서버 클립 우선 사용';
      case 'local':
        return '로컬 clipPath fallback 사용';
      default:
        if (item.clipUrl.trim().isNotEmpty) {
          return '서버 클립 우선 사용';
        }
        if (item.clipPath.trim().isNotEmpty) {
          return '로컬 clipPath fallback 사용';
        }
        return '사용 가능한 클립 정보 없음';
    }
  }

  String _resolveClipUrl(String clipUrl) {
    // /api/clips/파일명 형태의 상대 URL을 실제 접속 가능한 절대 URL로 바꿉니다.
    final trimmed = clipUrl.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return '';
    }

    final normalized = trimmed.toLowerCase();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '$_apiServerBaseUrl$trimmed';
    }
    return '$_apiServerBaseUrl/$trimmed';
  }

  Future<void> _watchExpectedLog({
    required String sourceType,
    required String sourceValue,
  }) async {
    // 파일 로그 모드에서는 입력 소스에 대응하는 txt 로그 경로를 계산해 watch를 시작합니다.
    final logPath = await appLinkService.buildLogPath(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );
    await logController.loadLog(logPath);
    final jsonEventLogPath = await appLinkService.buildJsonEventLogPath();
    await localEventJsonController.loadLog(jsonEventLogPath);
  }
}
