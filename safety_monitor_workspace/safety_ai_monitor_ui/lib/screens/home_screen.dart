import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/api_event_controller.dart';
import '../controllers/api_event_feed_source.dart';
import '../controllers/video_panel_controller.dart';
import '../models/api_event_item.dart';
import '../models/event_log_item.dart';
import '../models/frame_detection_snapshot.dart';
import '../models/source_item.dart';
import '../models/source_runtime_status.dart';
import '../models/video_overlay_detection.dart';
import '../services/event_api_service.dart';
import '../widgets/event_log_box.dart';
import '../widgets/file_bar.dart';
import '../widgets/video_control_bar.dart';
import '../widgets/video_view_box.dart';

// 메인 화면입니다.
// API 서버 기준 이벤트 표시와 영상 재생을 함께 조합합니다.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _defaultApiServerBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const Duration _apiAutoRefreshInterval = Duration(seconds: 3);
  late final VideoPanelController _emptyVideoController;
  late final EventApiService eventApiService;
  late final ApiEventController apiEventController;
  late final ApiEventFeedSource apiEventFeed;
  final ScrollController pageScrollController = ScrollController();
  final ScrollController rightPanelScrollController = ScrollController();
  final TextEditingController streamTextController = TextEditingController();
  final TextEditingController serverBaseUrlTextController =
      TextEditingController(text: _defaultApiServerBaseUrl);
  final List<_SourcePanelSlot> _sourceSlots = [];
  String _activeSlotId = '';
  ApiEventItem? selectedApiEventDetail;
  bool isLoadingApiDetail = false;
  String? apiDetailErrorMessage;
  Timer? apiAutoRefreshTimer;
  Timer? frameDetectionRefreshTimer;
  Timer? sourceStatusSyncTimer;
  DateTime? frameDetectionLogModifiedAt;
  String frameDetectionSourceKey = '';
  List<FrameDetectionSnapshot> frameDetectionSnapshots = const [];
  Map<String, SourceItem> registeredSourcesByKey = const {};
  Map<String, SourceRuntimeStatus> sourceStatusesByKey = const {};
  String lastFrameDetectionRequestSourceKey = '';
  double lastFrameDetectionRequestSeconds = -1;
  String lastFrameDetectionStatusUpdatedAt = '';
  late final String clientId;

  @override
  void initState() {
    super.initState();
    _emptyVideoController = VideoPanelController();
    eventApiService = EventApiService(baseUrl: _defaultApiServerBaseUrl);
    apiEventController = ApiEventController(service: eventApiService);
    apiEventFeed = ApiEventFeedSource(apiEventController);
    clientId = 'gui_${DateTime.now().microsecondsSinceEpoch}';
    unawaited(apiEventController.checkHealth());
    unawaited(_refreshApiEventsIfNeeded());
    _startApiAutoRefresh();
    _startFrameDetectionRefresh();
    _startSourceStatusSync();
    unawaited(_refreshSourceStatuses());
    unawaited(_refreshRegisteredSources());
  }

  @override
  void dispose() {
    apiAutoRefreshTimer?.cancel();
    frameDetectionRefreshTimer?.cancel();
    sourceStatusSyncTimer?.cancel();
    for (final slot in _sourceSlots) {
      slot.controller.disposeController();
    }
    _emptyVideoController.disposeController();
    apiEventFeed.dispose();
    pageScrollController.dispose();
    rightPanelScrollController.dispose();
    streamTextController.dispose();
    serverBaseUrlTextController.dispose();
    super.dispose();
  }

  _SourcePanelSlot? get _activeSlot {
    for (final slot in _sourceSlots) {
      if (slot.slotId == _activeSlotId) {
        return slot;
      }
    }
    return null;
  }

  VideoPanelController get videoController =>
      _activeSlot?.controller ?? _emptyVideoController;

  String get selectedSourceType => _activeSlot?.sourceType ?? '';

  String get selectedSourceValue => _activeSlot?.sourceValue ?? '';

  String get selectedSourceKey => _activeSlot?.sourceKey ?? '';

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
                    AnimatedBuilder(
                      animation: videoController,
                      builder: (context, _) {
                        return FileBar(
                          videoPath: videoController.videoPath,
                          sourceType: videoController.sourceType,
                            sourceHint: _buildSourceHint(),
                            sourceCount: _sourceSlots.length,
                            activeSourceLabel: _buildActiveSourceLabel(),
                            hasSelectedSource: selectedSourceKey.isNotEmpty,
                            canReturnFromReplay: videoController.canReturnFromReplay,
                            streamTextController: streamTextController,
                            onPickVideo: _pickVideoFile,
                            onClearSelectedSource: _clearSelectedSource,
                            onOpenStream: _openStream,
                            onReturnLive: _returnToLive,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSourceTabs(),
                    const SizedBox(height: 16),
                    _buildApiControls(),
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
                                            apiEventFeed,
                                          ],
                                        ),
                                        builder: (context, _) {
                                          // 오버레이는 현재 활성 feed에서 프레임 기준 이벤트만 받아 재사용합니다.
                                          return VideoViewBox(
                                            controller: videoController,
                                            overlayItems: _getOverlayItems(),
                                            overlayDetections: _getOverlayDetections(),
                                            overlaySourceWidth: _getOverlaySourceWidth(),
                                            overlaySourceHeight: _getOverlaySourceHeight(),
                                            overlayStatusText: _buildOverlayStatusText(),
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
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: AnimatedBuilder(
                                        animation: apiEventFeed,
                                        builder: (context, _) {
                                          return EventLogBox(
                                            eventFeed: apiEventFeed,
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

  Widget _buildApiControls() {
    // GUI는 API 서버를 기준으로 최신 이벤트를 polling 하며 재생 화면과 함께 보여 줍니다.
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
              Text(
                '이벤트 소스: API 서버',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              FilledButton(
                // 자동 polling이 있어도, 사용자가 즉시 다시 받고 싶을 때 수동 갱신할 수 있게 둡니다.
                onPressed: _refreshApiEvents,
                child: const Text('API 새로고침'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: serverBaseUrlTextController,
                  decoration: const InputDecoration(
                    labelText: '서버 주소',
                    hintText: 'http://192.168.0.10:8000',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => unawaited(_applyServerBaseUrl()),
                child: const Text('서버 적용'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: apiEventFeed,
            builder: (context, _) {
              return _buildApiStatusText();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTabs() {
    final activeSource = selectedSourceKey.isEmpty
        ? null
        : registeredSourcesByKey[selectedSourceKey.trim()];
    final activeStatus = selectedSourceKey.isEmpty
        ? null
        : sourceStatusesByKey[selectedSourceKey.trim()];
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
          Row(
            children: [
              Text(
                '소스 화면 전환',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '총 ${_sourceSlots.length}개',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_sourceSlots.isEmpty)
            Text(
              '영상 추가 또는 스트림 추가를 누르면 소스가 여기에 쌓이고, 칩을 눌러 화면을 전환할 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in _sourceSlots)
                  InputChip(
                    selected: slot.slotId == _activeSlotId,
                    avatar: CircleAvatar(
                      radius: 10,
                      backgroundColor: _colorForSlotStatus(slot),
                    ),
                    label: Text('${slot.label} · ${_describeSlotStatus(slot)}'),
                    onSelected: (_) => unawaited(_setActiveSlot(slot.slotId)),
                    onDeleted: () => _confirmRemoveSourceSlot(slot),
                  ),
              ],
            ),
          if (activeSource != null || activeStatus != null) ...[
            const SizedBox(height: 12),
            _buildActiveSourceRuntimeCard(
              source: activeSource,
              status: activeStatus,
            ),
          ],
          if (registeredSourcesByKey.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildRegisteredSourcesSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildRegisteredSourcesSummary() {
    final sourceEntries = registeredSourcesByKey.values.toList(growable: false)
      ..sort((left, right) => left.sourceKey.compareTo(right.sourceKey));
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
              '서버 등록 소스',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '소스별 이벤트/클립/업로드 원본 영상까지 함께 삭제하는 관리자용 기능을 제공합니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            for (final source in sourceEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.sourceSlug,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text('type: ${source.sourceType}'),
                      Text('source_key: ${source.sourceKey}'),
                      Text(
                        'state: ${_describeServerSourceState(source.sourceKey)}',
                      ),
                      Text(
                        'client: ${source.clientId.isEmpty ? '-' : source.clientId}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => unawaited(
                              _openRegisteredSource(source),
                            ),
                            child: const Text('화면에 열기'),
                          ),
                          OutlinedButton(
                            onPressed: () => unawaited(
                              _confirmDeleteRegisteredSource(source),
                            ),
                            child: const Text('서버 완전 삭제 (관리자용)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
  }

  Widget _buildActiveSourceRuntimeCard({
    required SourceItem? source,
    required SourceRuntimeStatus? status,
  }) {
    final normalizedState = status?.state.trim().isEmpty ?? true
        ? 'unknown'
        : status!.state.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 선택 소스 분석 상태',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text('source_key: ${source?.sourceKey ?? selectedSourceKey}'),
          Text('desired_running: ${source?.desiredRunning == true ? 'true' : 'false'}'),
          Text('state: $normalizedState'),
          Text('is_running: ${status?.isRunning == true ? 'true' : 'false'}'),
          Text('fps: ${status?.sourceFps.toStringAsFixed(1) ?? '0.0'}'),
          Text('last_frame: ${status?.lastFrameId ?? -1}'),
          Text(
            'last_time: ${status?.lastSourceTimeSeconds.toStringAsFixed(2) ?? '0.00'}s',
          ),
            if ((status?.errorMessage.trim() ?? '').isNotEmpty)
              Text(
                'error: ${status!.errorMessage.trim()}',
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              Text(
                '등록된 소스는 서버에서 자동으로 분석을 시작하고, 처리 완료 시 완료 상태로 표시됩니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
              if (source != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => unawaited(
                      _confirmDeleteRegisteredSource(source),
                    ),
                    child: const Text('현재 소스 서버 완전 삭제 (관리자용)'),
                  ),
                ),
              ],
            ],
          ),
        );
    }

  Widget _buildApiStatusText() {
    String text =
        '3초마다 자동 새로고침되며 "API 새로고침"으로 수동 갱신도 가능합니다.';

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

  String _buildFrameDetectionLabel(Map<String, dynamic> detection) {
    final name = (detection['name']?.toString().trim().isNotEmpty ?? false)
        ? detection['name'].toString().trim()
        : 'object';
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

  Color _colorForDetectionName(String name) {
    switch (name.trim().toLowerCase()) {
      case 'person':
        return Colors.lightBlueAccent;
      case 'helmet':
      case 'hardhat':
        return Colors.greenAccent;
      default:
        return Colors.orangeAccent;
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

    final existingSlot = _findSourceSlot(
      sourceType: 'video',
      sourceValue: file.path,
    );
    if (existingSlot != null) {
      if (existingSlot.controller.isReplayMode &&
          existingSlot.controller.canReturnFromReplay) {
        await existingSlot.controller.returnToLive();
      }
      await _setActiveSlot(existingSlot.slotId);
      await _syncFrameRateFromStatus(
        sourceType: existingSlot.sourceType,
        sourceValue: existingSlot.sourceValue,
        controller: existingSlot.controller,
      );
      if (mounted) {
        _showInfoSnack('이미 등록된 영상 소스로 전환했습니다.');
      }
      return;
    }

      final registeredSource = await _registerSourceOnServer(
        sourceType: 'video',
        sourceValue: file.path,
        resetExisting: true,
      );
      if (registeredSource == null) {
        return;
      }
      final slot = await _addOrActivateSourceSlot(
        sourceType: registeredSource.sourceType,
        sourceValue: registeredSource.sourceValue,
        openPath: file.path,
        sourceKey: registeredSource.sourceKey,
        originalSourceType: registeredSource.originalSourceType,
        originalSourceValue: file.path,
      );
    await _syncFrameRateFromStatus(
      sourceType: registeredSource.sourceType,
      sourceValue: registeredSource.sourceValue,
      controller: slot.controller,
    );
    unawaited(_refreshApiEventsIfNeeded());
  }

  Future<void> _openStream() async {
    final streamUrl = streamTextController.text.trim();
    if (streamUrl.isEmpty) {
      return;
    }

    final existingSlot = _findSourceSlot(
      sourceType: 'stream',
      sourceValue: streamUrl,
    );
    if (existingSlot != null) {
      if (existingSlot.controller.isReplayMode &&
          existingSlot.controller.canReturnFromReplay) {
        await existingSlot.controller.returnToLive();
      }
      await _setActiveSlot(existingSlot.slotId);
      await _syncFrameRateFromStatus(
        sourceType: existingSlot.sourceType,
        sourceValue: existingSlot.sourceValue,
        controller: existingSlot.controller,
      );
      if (mounted) {
        _showInfoSnack('이미 등록된 스트림 소스로 전환했습니다.');
      }
      return;
    }

    final registeredSource = await _registerSourceOnServer(
      sourceType: 'stream',
      sourceValue: streamUrl,
      resetExisting: true,
    );
    if (registeredSource == null) {
      return;
    }
    final slot = await _addOrActivateSourceSlot(
      sourceType: registeredSource.sourceType,
      sourceValue: registeredSource.sourceValue,
      openPath: registeredSource.sourceValue,
      nextSourceType: registeredSource.sourceType,
      sourceKey: registeredSource.sourceKey,
      originalSourceType: registeredSource.originalSourceType,
      originalSourceValue: registeredSource.originalSourceValue,
    );
    await _syncFrameRateFromStatus(
      sourceType: registeredSource.sourceType,
      sourceValue: registeredSource.sourceValue,
      controller: slot.controller,
    );
    unawaited(_refreshApiEventsIfNeeded());
  }

  List<EventLogItem> _getOverlayItems() {
    if (!videoController.hasVideo || _effectiveOverlaySourceKey().isEmpty) {
      return const [];
    }

    return apiEventController.getLogItemsForTime(
      videoController.currentOverlaySeconds,
    );
  }

  FrameDetectionSnapshot? _getOverlaySnapshot() {
    if (_effectiveOverlaySourceKey().isEmpty || frameDetectionSnapshots.isEmpty) {
      return null;
    }

    if (frameDetectionSnapshots.length == 1) {
      return frameDetectionSnapshots.first;
    }

    final currentSeconds = videoController.currentOverlaySeconds;
    FrameDetectionSnapshot? beforeOrEqual;
    FrameDetectionSnapshot? after;

    for (final snapshot in frameDetectionSnapshots) {
      if (snapshot.sourceTimeSeconds <= currentSeconds) {
        beforeOrEqual = snapshot;
        continue;
      }
      after = snapshot;
      break;
    }

    final frameTolerance = math.max(
      0.08,
      (videoController.frameRate <= 0 ? 1 / 30 : 1 / videoController.frameRate) *
          1.5,
    );

    FrameDetectionSnapshot? best;
    if (beforeOrEqual != null &&
        (currentSeconds - beforeOrEqual.sourceTimeSeconds).abs() <=
            frameTolerance) {
      best = beforeOrEqual;
    }
    if (after != null &&
        (after.sourceTimeSeconds - currentSeconds).abs() <= frameTolerance) {
      if (best == null ||
          (after.sourceTimeSeconds - currentSeconds).abs() <
              (best.sourceTimeSeconds - currentSeconds).abs()) {
        best = after;
      }
    }

    return best;
  }

  List<VideoOverlayDetection> _getOverlayDetections() {
    final snapshot = _getOverlaySnapshot();
    if (snapshot == null) {
      return const [];
    }

    final detections = <VideoOverlayDetection>[];
    final seenKeys = <String>{};
    for (final detection in snapshot.detections) {
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
          '${snapshot.frameId}:${detection['track_id']}:${detection['name']}:$x1:$y1:$x2:$y2';
      if (!seenKeys.add(key)) {
        continue;
      }

      detections.add(
        VideoOverlayDetection(
          key: key,
          label: _buildFrameDetectionLabel(detection),
          color: _colorForDetectionName(detection['name']?.toString() ?? ''),
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
        ),
      );
    }

    return detections;
  }

  double _getOverlaySourceWidth() {
    final snapshot = _getOverlaySnapshot();
    if (snapshot != null && snapshot.frameWidth > 0) {
      return snapshot.frameWidth.toDouble();
    }
    return videoController.videoWidth.toDouble();
  }

  double _getOverlaySourceHeight() {
    final snapshot = _getOverlaySnapshot();
    if (snapshot != null && snapshot.frameHeight > 0) {
      return snapshot.frameHeight.toDouble();
    }
    return videoController.videoHeight.toDouble();
  }

  String _effectiveOverlaySourceKey() {
    if (videoController.isReplayMode && videoController.replaySourceKey.isNotEmpty) {
      return videoController.replaySourceKey;
    }
    return selectedSourceKey;
  }

  Future<void> _onTapEventItem(EventLogItem item) async {
    // 클릭 공통 동작:
    // 1) 선택 표시
    // 2) API 상세 조회
    // 3) 이벤트 시작 시점으로 이동
    apiEventFeed.selectLogItem(item);

    final eventKey = item.eventKeyText.trim();
    ApiEventItem? detail;
    final preferredSourceKey = selectedSourceKey.trim().isNotEmpty
        ? selectedSourceKey.trim()
        : apiEventController.visibleSourceKey.trim();
    if (eventKey.isNotEmpty && eventKey != '-') {
      setState(() {
        isLoadingApiDetail = true;
        apiDetailErrorMessage = null;
        selectedApiEventDetail = null;
      });

      try {
        detail = await apiEventController.loadEventDetail(
          eventKey,
          sourceKey: preferredSourceKey.isEmpty ? null : preferredSourceKey,
        );
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

      final sourceItem = apiEventController.findItemByEventKey(item.eventKeyText) ?? detail;
      if (sourceItem == null) {
        return;
      }
      if (selectedSourceKey.trim().isEmpty) {
        if (mounted) {
          _showInfoSnack('이벤트 시작 시점으로 이동하려면 먼저 해당 영상 소스를 선택해 주세요.');
        }
        return;
      }
      if (selectedSourceKey.trim() != sourceItem.sourceKey.trim()) {
        if (mounted) {
          _showInfoSnack('현재 선택된 영상 소스의 이벤트만 이동할 수 있습니다.');
        }
        return;
      }
      final targetSeconds = _resolveEventStartSeconds(sourceItem);
    if (targetSeconds < 0) {
      return;
    }

    if (videoController.isReplayMode && videoController.canReturnFromReplay) {
      await videoController.returnToLive();
    }

    if (videoController.sourceType == 'stream') {
      return;
    }

    final targetMs = (targetSeconds * 1000).round();
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
    // API 상세 패널의 "클립 열기"는 서버 clip_url/server_clip_path를 우선 사용하고,
    // 둘 다 없을 때만 레거시 local clipPath를 fallback으로 사용합니다.
    final resolvedPath = _resolveApiClipSource(item);
    if (resolvedPath.isEmpty) {
      setState(() {
        apiDetailErrorMessage = '클립 경로가 비어 있습니다.';
      });
      return;
    }

    try {
      final targetBinding = await _resolveClipTargetController(item);
      final targetController = targetBinding.controller;
      await targetController.openReplayClip(
        resolvedPath,
        replayStartSeconds: _resolveEventStartSeconds(item),
        sourceKey: item.sourceKey,
        preserveReturnContext: targetBinding.preserveReturnContext,
      );
      await _refreshFrameDetectionsForSource(item.sourceKey);
      if (mounted) {
        _showInfoSnack('이벤트 클립을 열었습니다.');
      }
    } catch (error) {
      setState(() {
        apiDetailErrorMessage = '클립을 열 수 없습니다: $error';
      });
    }
  }

  double _resolveEventStartSeconds(ApiEventItem? item) {
    if (item == null) {
      return 0.0;
    }

    final parsed = _parseVideoTimeText(item.startedSourceTimeText);
    if (parsed != null) {
      return parsed;
    }
    return item.sourceTimeSeconds < 0 ? 0.0 : item.sourceTimeSeconds;
  }

  double? _parseVideoTimeText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return null;
    }

    final parts = trimmed.split(':');
    if (parts.length < 2 || parts.length > 3) {
      return null;
    }

    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final seconds = double.tryParse(parts[1]);
      if (minutes == null || seconds == null) {
        return null;
      }
      return (minutes * 60) + seconds;
    }

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = double.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) {
      return null;
    }
    return (hours * 3600) + (minutes * 60) + seconds;
  }

  Future<void> _refreshApiEvents() async {
    await apiEventController.loadEvents(limit: 5000);
  }

  Future<void> _checkApiHealth() async {
    await apiEventController.checkHealth();
  }

  Future<void> _applyServerBaseUrl() async {
    final nextBaseUrl = serverBaseUrlTextController.text.trim();
    if (nextBaseUrl.isEmpty) {
      return;
    }
    eventApiService.updateBaseUrl(nextBaseUrl);
    await apiEventController.checkHealth();
    await _refreshRegisteredSources();
    await _refreshSourceStatuses();
    await _refreshApiEventsIfNeeded();
    if (mounted) {
      _showInfoSnack('서버 주소를 ${eventApiService.baseUrl} 로 적용했습니다.');
    }
  }

  Future<SourceItem?> _registerSourceOnServer({
    required String sourceType,
    required String sourceValue,
    bool resetExisting = true,
  }) async {
    final registeredSource = sourceType.trim() == 'video'
        ? await eventApiService.uploadVideoSource(
            filePath: sourceValue,
            clientId: clientId,
            resetExisting: resetExisting,
            startImmediately: true,
          )
        : await eventApiService.registerSource(
            sourceType: sourceType,
            sourceValue: sourceValue,
            clientId: clientId,
            resetExisting: resetExisting,
            startImmediately: true,
          );
    if (registeredSource == null && mounted) {
      setState(() {
        apiDetailErrorMessage = sourceType.trim() == 'video'
            ? '서버에 영상 파일을 업로드하지 못했습니다.'
            : '서버에 소스를 등록하지 못했습니다.';
        selectedApiEventDetail = null;
      });
      return null;
    }

    if (mounted) {
      setState(() {
        apiDetailErrorMessage = null;
        selectedApiEventDetail = null;
      });
    }
    unawaited(_refreshRegisteredSources());
    unawaited(_refreshSourceStatuses());
    return registeredSource;
  }

  void _startApiAutoRefresh() {
    // 실시간 push(WebSocket) 대신 3초 간격 polling으로 서버 최신 이벤트를 가져옵니다.
    _stopApiAutoRefresh();
    apiAutoRefreshTimer = Timer.periodic(_apiAutoRefreshInterval, (_) {
      unawaited(_refreshApiEventsIfNeeded());
    });
  }

  void _startFrameDetectionRefresh() {
    frameDetectionRefreshTimer?.cancel();
    frameDetectionRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        unawaited(_refreshFrameDetectionsIfNeeded());
      },
    );
  }

  void _startSourceStatusSync() {
    sourceStatusSyncTimer?.cancel();
    sourceStatusSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshSourceStatuses());
      unawaited(_refreshRegisteredSources());
      unawaited(_syncActiveSlotFrameRateIfNeeded());
    });
  }

  void _stopApiAutoRefresh() {
    apiAutoRefreshTimer?.cancel();
    apiAutoRefreshTimer = null;
  }

  Future<void> _refreshApiEventsIfNeeded() async {
    if (!mounted) {
      return;
    }
    if (apiEventController.isLoading) {
      // 이미 요청 중이면 중복 호출을 피해서 화면 흔들림과 불필요한 서버 호출을 줄입니다.
      return;
    }
    await _refreshApiEvents();
  }

  Future<void> _refreshFrameDetectionsIfNeeded() async {
    if (!mounted) {
      return;
    }

    final sourceKey = _effectiveOverlaySourceKey();
    if (sourceKey.isEmpty) {
      if (frameDetectionSnapshots.isNotEmpty || frameDetectionSourceKey.isNotEmpty) {
        setState(() {
          frameDetectionSnapshots = const [];
          frameDetectionLogModifiedAt = null;
          frameDetectionSourceKey = '';
          lastFrameDetectionRequestSourceKey = '';
          lastFrameDetectionRequestSeconds = -1;
          lastFrameDetectionStatusUpdatedAt = '';
        });
      }
      return;
    }

    final currentOverlaySeconds = videoController.currentOverlaySeconds;
    final runtimeStatus = sourceStatusesByKey[sourceKey.trim()];
    final frameIntervalSeconds = videoController.frameRate <= 0
        ? (1 / 30)
        : (1 / videoController.frameRate);
    final isLiveLikeSource = videoController.isStreamMode && !videoController.isReplayMode;
    final movedEnough = lastFrameDetectionRequestSourceKey != sourceKey ||
        (currentOverlaySeconds - lastFrameDetectionRequestSeconds).abs() >=
            (frameIntervalSeconds * 0.5);
    final statusChanged = (runtimeStatus?.updatedAt ?? '') !=
        lastFrameDetectionStatusUpdatedAt;
    final isTerminalState = runtimeStatus != null &&
        (runtimeStatus.state == 'completed' ||
            runtimeStatus.state == 'stopped' ||
            runtimeStatus.state == 'error');
    final hasUsableSnapshot = frameDetectionSourceKey == sourceKey &&
        frameDetectionSnapshots.isNotEmpty &&
        (!isLiveLikeSource
            ? (frameDetectionSnapshots.first.sourceTimeSeconds - currentOverlaySeconds)
                    .abs() <=
                math.max(0.08, frameIntervalSeconds * 1.5)
            : true);
    if (!videoController.isPlaying &&
        !statusChanged &&
        isTerminalState &&
        hasUsableSnapshot) {
      return;
    }
    if (!movedEnough && !statusChanged) {
      return;
    }

    final FrameDetectionSnapshot? snapshot;
    if (isLiveLikeSource) {
      snapshot = await eventApiService.fetchLatestFrameDetection(
        sourceKey: sourceKey,
      );
    } else {
      final toleranceSeconds = math.max(
        0.20,
        frameIntervalSeconds * 4.0,
      );
      snapshot = await eventApiService.fetchCurrentFrameDetection(
        sourceKey: sourceKey,
        sourceTimeSeconds: currentOverlaySeconds,
        toleranceSeconds: toleranceSeconds,
      );
    }
    if (!mounted) {
      return;
    }

    setState(() {
      frameDetectionSnapshots = snapshot == null ? const [] : [snapshot];
      frameDetectionLogModifiedAt = DateTime.now();
      frameDetectionSourceKey = sourceKey;
      lastFrameDetectionRequestSourceKey = sourceKey;
      lastFrameDetectionRequestSeconds = currentOverlaySeconds;
      lastFrameDetectionStatusUpdatedAt = runtimeStatus?.updatedAt ?? '';
    });
  }

  Future<void> _refreshFrameDetectionsForSource(String sourceKey) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty) {
      return;
    }

    final isLiveLikeSource = videoController.isStreamMode && !videoController.isReplayMode;
    final FrameDetectionSnapshot? snapshot;
    if (isLiveLikeSource) {
      snapshot = await eventApiService.fetchLatestFrameDetection(
        sourceKey: normalizedSourceKey,
      );
    } else {
      final toleranceSeconds = math.max(
        0.20,
        (videoController.frameRate <= 0 ? 1 / 30 : 1 / videoController.frameRate) *
            4.0,
      );
      snapshot = await eventApiService.fetchCurrentFrameDetection(
        sourceKey: normalizedSourceKey,
        sourceTimeSeconds: videoController.currentOverlaySeconds,
        toleranceSeconds: toleranceSeconds,
      );
    }
    if (!mounted) {
      return;
    }

    setState(() {
      frameDetectionSnapshots = snapshot == null ? const [] : [snapshot];
      frameDetectionLogModifiedAt = DateTime.now();
      frameDetectionSourceKey = normalizedSourceKey;
      lastFrameDetectionRequestSourceKey = normalizedSourceKey;
      lastFrameDetectionRequestSeconds = videoController.currentOverlaySeconds;
      lastFrameDetectionStatusUpdatedAt =
          sourceStatusesByKey[normalizedSourceKey]?.updatedAt ?? '';
    });
  }

  String _resolveApiClipSource(ApiEventItem item) {
    // 서버가 clip_url 또는 server_clip_path를 돌려준 경우 이를 우선 사용합니다.
    final clipUrl = item.clipUrl.trim();
    if (clipUrl.isNotEmpty && clipUrl != '-') {
      return _resolveClipUrl(clipUrl);
    }
    final serverClipPath = item.serverClipPath.trim();
    if (serverClipPath.isNotEmpty && serverClipPath != '-') {
      return _resolveClipUrl(serverClipPath);
    }
    final clipPath = item.clipPath.trim();
    if (clipPath.isEmpty || clipPath == '-') {
      return '';
    }
    return clipPath;
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
      return '${eventApiService.baseUrl}$trimmed';
    }
    return '${eventApiService.baseUrl}/$trimmed';
  }

  Future<_SourcePanelSlot> _addOrActivateSourceSlot({
    required String sourceType,
    required String sourceValue,
    required String openPath,
    required String sourceKey,
    String? originalSourceType,
    String? originalSourceValue,
    String? nextSourceType,
  }) async {
    for (final slot in _sourceSlots) {
      if (slot.sourceKey != sourceKey) {
        continue;
      }
      await _setActiveSlot(slot.slotId);
      apiEventController.setVisibleSourceKey(sourceKey);
      unawaited(_refreshApiEventsIfNeeded());
      unawaited(_refreshFrameDetectionsIfNeeded());
      return slot;
    }

      final slot = _SourcePanelSlot(
        slotId: 'slot_${DateTime.now().microsecondsSinceEpoch}',
        sourceType: sourceType,
        sourceValue: sourceValue,
        sourceKey: sourceKey,
        originalSourceType: originalSourceType ?? sourceType,
        originalSourceValue: originalSourceValue ?? sourceValue,
        label: _buildSlotLabel(
          sourceType: originalSourceType ?? sourceType,
          sourceValue: originalSourceValue ?? sourceValue,
        ),
        controller: VideoPanelController(),
      );
    await slot.controller.openVideo(
      openPath,
      nextSourceType: nextSourceType ?? sourceType,
    );

    setState(() {
      _sourceSlots.add(slot);
      _activeSlotId = slot.slotId;
      selectedApiEventDetail = null;
      apiDetailErrorMessage = null;
      frameDetectionSnapshots = const [];
      frameDetectionLogModifiedAt = null;
      frameDetectionSourceKey = '';
    });
    await _pauseInactiveSlots(exceptSlotId: slot.slotId);
    apiEventController.setVisibleSourceKey(sourceKey);
    unawaited(_refreshApiEventsIfNeeded());
    unawaited(_refreshFrameDetectionsIfNeeded());
    return slot;
  }

  Future<void> _removeSourceSlot(String slotId) async {
    _SourcePanelSlot? removedSlot;
    final nextSlots = <_SourcePanelSlot>[];
    for (final slot in _sourceSlots) {
      if (slot.slotId == slotId) {
        removedSlot = slot;
        continue;
      }
      nextSlots.add(slot);
    }
    if (removedSlot == null) {
      return;
    }

    removedSlot.controller.disposeController();
    setState(() {
      _sourceSlots
        ..clear()
        ..addAll(nextSlots);
      if (_activeSlotId == slotId) {
        _activeSlotId = _sourceSlots.isEmpty ? '' : _sourceSlots.last.slotId;
      }
      selectedApiEventDetail = null;
      apiDetailErrorMessage = null;
      frameDetectionSnapshots = const [];
      frameDetectionLogModifiedAt = null;
      frameDetectionSourceKey = '';
    });

    apiEventFeed.clearSelection();
    apiEventController.setVisibleSourceKey(selectedSourceKey);
    await eventApiService.deleteSource(removedSlot.sourceKey, clearData: false);
    await _refreshRegisteredSources();
    await _refreshSourceStatuses();
    if (_sourceSlots.isNotEmpty) {
      await _syncActiveSlotFrameRateIfNeeded();
    }
    unawaited(_refreshApiEventsIfNeeded());
    unawaited(_refreshFrameDetectionsIfNeeded());
  }

  Future<void> _removeLocalSlotBySourceKey(String sourceKey) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty) {
      return;
    }

    _SourcePanelSlot? removedSlot;
    final nextSlots = <_SourcePanelSlot>[];
    for (final slot in _sourceSlots) {
      if (slot.sourceKey.trim() == normalizedSourceKey) {
        removedSlot = slot;
        continue;
      }
      nextSlots.add(slot);
    }
    if (removedSlot == null) {
      return;
    }

    removedSlot.controller.disposeController();
    setState(() {
      _sourceSlots
        ..clear()
        ..addAll(nextSlots);
      if (_activeSlotId == removedSlot!.slotId) {
        _activeSlotId = _sourceSlots.isEmpty ? '' : _sourceSlots.last.slotId;
      }
      selectedApiEventDetail = null;
      apiDetailErrorMessage = null;
      frameDetectionSnapshots = const [];
      frameDetectionLogModifiedAt = null;
      frameDetectionSourceKey = '';
    });

    apiEventFeed.clearSelection();
    apiEventController.setVisibleSourceKey(selectedSourceKey);
    if (_sourceSlots.isNotEmpty) {
      await _syncActiveSlotFrameRateIfNeeded();
    }
    unawaited(_refreshApiEventsIfNeeded());
    unawaited(_refreshFrameDetectionsIfNeeded());
  }

  Future<void> _setActiveSlot(String slotId) async {
    if (_activeSlotId == slotId) {
      return;
    }
    setState(() {
      _activeSlotId = slotId;
      selectedApiEventDetail = null;
      apiDetailErrorMessage = null;
      frameDetectionSnapshots = const [];
      frameDetectionLogModifiedAt = null;
      frameDetectionSourceKey = '';
    });
    await _pauseInactiveSlots(exceptSlotId: slotId);
    apiEventFeed.clearSelection();
    apiEventController.setVisibleSourceKey(selectedSourceKey);
    unawaited(_refreshApiEventsIfNeeded());
    unawaited(_syncActiveSlotFrameRateIfNeeded());
    unawaited(_refreshFrameDetectionsIfNeeded());
  }

  Future<void> _pauseInactiveSlots({required String exceptSlotId}) async {
    for (final slot in _sourceSlots) {
      if (slot.slotId == exceptSlotId) {
        continue;
      }
      await slot.controller.pausePlayback();
    }
  }

  String _buildSlotLabel({
    required String sourceType,
    required String sourceValue,
  }) {
    if (sourceType == 'video') {
      final normalized = sourceValue.replaceAll('\\', '/');
      final parts = normalized.split('/');
      return parts.isEmpty ? sourceValue : parts.last;
    }
    return sourceValue;
  }

  Future<void> _syncFrameRateFromStatus({
    required String sourceType,
    required String sourceValue,
    required VideoPanelController controller,
  }) async {
    final sourceKey = _buildSourceKey(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );
    final runtimeStatus = sourceStatusesByKey[sourceKey.trim()];
    if (runtimeStatus == null) {
      return;
    }

    if (runtimeStatus.sourceType.trim() != sourceType.trim()) {
      return;
    }

    if (!_isSameSourceValue(runtimeStatus.sourceValue, sourceValue)) {
      return;
    }

    controller.setFrameRate(runtimeStatus.sourceFps);
  }

  Future<void> _refreshSourceStatuses() async {
    final entries = await eventApiService.fetchSourceStatuses();
    if (!mounted) {
      return;
    }

    final nextMap = <String, SourceRuntimeStatus>{};
    for (final entry in entries) {
      final sourceKey = entry.sourceKey.trim();
      if (sourceKey.isEmpty) {
        continue;
      }
      nextMap[sourceKey] = entry;
    }

    setState(() {
      sourceStatusesByKey = nextMap;
    });
  }

  Future<void> _refreshRegisteredSources() async {
    final items = await eventApiService.fetchSources();
    if (!mounted) {
      return;
    }

    final nextMap = <String, SourceItem>{};
    for (final item in items) {
      final sourceKey = item.sourceKey.trim();
      if (sourceKey.isEmpty) {
        continue;
      }
      nextMap[sourceKey] = item;
    }

    setState(() {
      registeredSourcesByKey = nextMap;
    });
  }

  bool _isSameSourceValue(String left, String right) {
    final normalizedLeft = left.trim().replaceAll('\\', '/').toLowerCase();
    final normalizedRight = right.trim().replaceAll('\\', '/').toLowerCase();
    return normalizedLeft == normalizedRight;
  }

  String _buildSourceHint() {
    if (selectedSourceKey.isEmpty) {
      return '소스를 추가하고 칩을 눌러 화면을 전환할 수 있습니다. 선택된 소스가 없으면 전체 이벤트 로그를 표시합니다.';
    }

    return '현재 화면의 소스 로그와 객체 박스만 표시하며, 분석 상태는 서버에서 계속 갱신됩니다.';
  }

  String _buildOverlayStatusText() {
    if (!videoController.hasVideo) {
      return '';
    }

    if (videoController.errorText.trim().isNotEmpty) {
      return '영상 재생 오류: ${videoController.errorText.trim()}';
    }

    final sourceKey = _effectiveOverlaySourceKey().trim();
    if (sourceKey.isEmpty) {
      return '선택된 소스가 없어 전체 로그만 표시 중입니다.';
    }

    if (videoController.isReplayMode) {
      return '클립 재생 중입니다. 박스는 원본 영상 시간축 기준으로 맞춰집니다.';
    }

    if (!sourceStatusesByKey.containsKey(sourceKey)) {
      return '이 소스 분석 준비 중입니다. Python worker가 서버에 상태를 보내면 박스가 갱신됩니다.';
    }

    final status = sourceStatusesByKey[sourceKey];

    if (frameDetectionSourceKey != sourceKey || frameDetectionSnapshots.isEmpty) {
      return '아직 이 소스의 프레임 탐지 결과를 기다리는 중입니다.';
    }

    final snapshot = _getOverlaySnapshot();
    if (snapshot != null) {
      final snapshotTimeDelta =
          (snapshot.sourceTimeSeconds - videoController.currentOverlaySeconds).abs();
      if (snapshotTimeDelta <= 0.15) {
        if (snapshot.detections.isEmpty) {
          return '현재 시점에는 탐지된 객체가 없습니다.';
        }
        return '';
      }
    }

    if (snapshot == null) {
      return '현재 재생 시점과 맞는 분석 프레임을 기다리는 중입니다.';
    }

    if (status != null &&
        status.state.trim().toLowerCase() != 'completed' &&
        status.lastSourceTimeSeconds + 0.02 < videoController.currentOverlaySeconds) {
      return '현재 재생 시점은 아직 Python 분석이 끝나지 않았습니다.';
    }

    if (snapshot.detections.isEmpty) {
      return '현재 시점에는 탐지된 객체가 없습니다.';
    }

    return '';
  }

  String _buildActiveSourceLabel() {
    final slot = _activeSlot;
    if (slot == null) {
      if (_sourceSlots.isEmpty) {
        return '없음';
      }
      return '전체 로그 보기';
    }
    return slot.label;
  }

  _SourcePanelSlot? _findSourceSlotByKey(String sourceKey) {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty) {
      return null;
    }
    for (final slot in _sourceSlots) {
      if (slot.sourceKey.trim() == normalizedSourceKey) {
        return slot;
      }
    }
    return null;
  }

  _SourcePanelSlot? _findSourceSlot({
    required String sourceType,
    required String sourceValue,
  }) {
    final nextSourceKey = _buildSourceKey(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );
    for (final slot in _sourceSlots) {
      if (slot.sourceKey == nextSourceKey) {
        return slot;
      }
      if (slot.originalSourceType.trim() == sourceType.trim() &&
          _isSameSourceValue(slot.originalSourceValue, sourceValue)) {
        return slot;
      }
    }
    return null;
  }

  Future<void> _syncActiveSlotFrameRateIfNeeded() async {
    final slot = _activeSlot;
    if (slot == null) {
      return;
    }
    await _syncFrameRateFromStatus(
      sourceType: slot.sourceType,
      sourceValue: slot.sourceValue,
      controller: slot.controller,
    );
  }

  Future<bool> _activateSlotForSourceKey(String sourceKey) async {
    final targetSlot = _findSourceSlotByKey(sourceKey);
    if (targetSlot == null) {
      return false;
    }
    if (_activeSlotId != targetSlot.slotId) {
      await _setActiveSlot(targetSlot.slotId);
    }
    await _syncFrameRateFromStatus(
      sourceType: targetSlot.sourceType,
      sourceValue: targetSlot.sourceValue,
      controller: targetSlot.controller,
    );
    return true;
  }

  Future<bool> _ensureSlotForEventSource(ApiEventItem item) async {
    final activated = await _activateSlotForSourceKey(item.sourceKey);
    if (activated) {
      return true;
    }

    final sourceType = item.sourceType.trim();
    final sourceValue = item.sourceValue.trim();
    if (sourceType.isEmpty || sourceValue.isEmpty) {
      return false;
    }

    try {
      await _addOrActivateSourceSlot(
        sourceType: sourceType,
        sourceValue: sourceValue,
        openPath: sourceValue,
        sourceKey: item.sourceKey,
        originalSourceType: sourceType,
        originalSourceValue: sourceValue,
        nextSourceType: sourceType,
      );
      await _syncActiveSlotFrameRateIfNeeded();
      if (mounted) {
        _showInfoSnack('이벤트 원본 소스를 화면에 추가하고 전환했습니다.');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<_ClipTargetBinding> _resolveClipTargetController(ApiEventItem item) async {
    final ensured = await _ensureSlotForEventSource(item);
    if (ensured) {
      final targetSlot = _findSourceSlotByKey(item.sourceKey);
      if (targetSlot != null) {
        return _ClipTargetBinding(
          controller: targetSlot.controller,
          preserveReturnContext: true,
        );
      }
    }

    if (mounted) {
      _showInfoSnack('원본 소스를 열 수 없어 현재 화면에서 클립만 재생합니다.');
    }
    return _ClipTargetBinding(
      controller: videoController,
      preserveReturnContext: false,
    );
  }

  Future<void> _confirmRemoveSourceSlot(_SourcePanelSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('소스 닫기'),
          content: Text('"${slot.label}" 소스 화면을 닫고 분석도 중단합니다. 계속할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _removeSourceSlot(slot.slotId);
    if (mounted) {
      _showInfoSnack('"${slot.label}" 소스 분석을 중단하고 화면에서 제거했습니다.');
    }
  }

  Future<void> _confirmDeleteRegisteredSource(SourceItem source) async {
    final runtimeStatus = sourceStatusesByKey[source.sourceKey];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('서버 소스 완전 삭제 (관리자용)'),
          content: Text(
            '"${source.sourceSlug}"\n'
            'type: ${source.sourceType}\n'
            'state: ${runtimeStatus?.state ?? 'unknown'}\n\n'
            '이 소스와 관련된 서버 이벤트 로그, 프레임 탐지 데이터, 클립 파일, 업로드 원본 영상을 함께 삭제합니다. 계속할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('서버 완전 삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final ok = await eventApiService.deleteSource(
      source.sourceKey,
      clearData: true,
    );
    if (!ok) {
      if (mounted) {
        _showInfoSnack('서버 소스 삭제에 실패했습니다.');
      }
      return;
    }

    await _removeLocalSlotBySourceKey(source.sourceKey);
    await _refreshRegisteredSources();
    await _refreshSourceStatuses();
    unawaited(_refreshApiEventsIfNeeded());
    unawaited(_refreshFrameDetectionsIfNeeded());

    if (mounted) {
      _showInfoSnack('"${source.sourceSlug}" 서버 데이터 삭제를 완료했습니다. (관리자용)');
    }
  }

  Future<void> _openRegisteredSource(SourceItem source) async {
    final existingSlot = _findSourceSlotByKey(source.sourceKey);
    if (existingSlot != null) {
      await _setActiveSlot(existingSlot.slotId);
      return;
    }

    final openPath = _resolveRegisteredSourceOpenPath(source);
    if (openPath.isEmpty) {
      if (mounted) {
        _showInfoSnack('이 소스는 현재 화면에서 열 수 있는 재생 경로가 없습니다.');
      }
      return;
    }

    await _addOrActivateSourceSlot(
      sourceType: source.sourceType,
      sourceValue: source.sourceValue,
      openPath: openPath,
      nextSourceType: source.sourceType,
      sourceKey: source.sourceKey,
      originalSourceType: source.originalSourceType,
      originalSourceValue: source.originalSourceValue,
    );
    await _syncActiveSlotFrameRateIfNeeded();
    if (mounted) {
      _showInfoSnack('"${source.sourceSlug}" 소스를 화면에 열었습니다.');
    }
  }

  String _resolveRegisteredSourceOpenPath(SourceItem source) {
    final sourceType = source.sourceType.trim().toLowerCase();
    if (sourceType == 'stream') {
      final original = source.originalSourceValue.trim();
      if (original.isNotEmpty) {
        return original;
      }
      return source.sourceValue.trim();
    }

    final mediaUrl = source.mediaUrl.trim();
    if (mediaUrl.isNotEmpty) {
      return _resolveClipUrl(mediaUrl);
    }

    final original = source.originalSourceValue.trim();
    if (original.isNotEmpty) {
      return original;
    }
    return source.sourceValue.trim();
  }

  String _describeServerSourceState(String sourceKey) {
    final normalized = sourceKey.trim();
    if (normalized.isEmpty) {
      return 'unknown';
    }
    final runtimeStatus = sourceStatusesByKey[normalized];
    if (runtimeStatus == null) {
      return 'unknown';
    }
    final state = runtimeStatus.state.trim().toLowerCase();
    if (state == 'completed') {
      return 'complete';
    }
    return runtimeStatus.state.trim().isEmpty ? 'unknown' : runtimeStatus.state.trim();
  }

  String _describeSlotStatus(_SourcePanelSlot slot) {
    final sourceKey = slot.sourceKey.trim();
    if (slot.controller.errorText.trim().isNotEmpty) {
      return '오류';
    }
    final runtimeStatus = sourceStatusesByKey[sourceKey];
    if (runtimeStatus == null) {
      return '준비중';
    }
    if (runtimeStatus.errorMessage.trim().isNotEmpty ||
        runtimeStatus.state.trim().toLowerCase() == 'error') {
      return '오류';
    }
    final runtimeState = runtimeStatus.state.trim().toLowerCase();
    if (runtimeState == 'completed') {
      final hasEvents = apiEventController.items.any(
        (item) => item.sourceKey.trim() == sourceKey,
      );
      return hasEvents ? '분석 완료 · 이벤트 있음' : '분석 완료';
    }
    if (runtimeState == 'source_changed' || runtimeState == 'stopped') {
      return '중지됨';
    }
    if (slot.slotId == _activeSlotId &&
        frameDetectionSourceKey == sourceKey &&
        frameDetectionSnapshots.isNotEmpty) {
      return '분석중';
    }
    final hasEvents = apiEventController.items.any(
      (item) => item.sourceKey.trim() == sourceKey,
    );
    if (hasEvents) {
      return '이벤트 있음';
    }
    if (runtimeStatus.isRunning) {
      return '백그라운드 분석';
    }
    return '대기중';
  }

  Color _colorForSlotStatus(_SourcePanelSlot slot) {
    switch (_describeSlotStatus(slot)) {
      case '오류':
        return Colors.redAccent;
      case '분석중':
        return Colors.green;
      case '이벤트 있음':
        return Colors.orangeAccent;
      case '백그라운드 분석':
        return Colors.blueAccent;
      case '대기중':
        return Colors.blueGrey;
      case '분석 완료':
        return Colors.teal;
      case '분석 완료 · 이벤트 있음':
        return Colors.tealAccent.shade700;
      case '중지됨':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  void _showInfoSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearSelectedSource() async {
    apiEventFeed.clearSelection();
    if (_activeSlotId.isNotEmpty) {
      setState(() {
        _activeSlotId = '';
        selectedApiEventDetail = null;
        apiDetailErrorMessage = null;
        frameDetectionSnapshots = const [];
        frameDetectionLogModifiedAt = null;
        frameDetectionSourceKey = '';
      });
      if (mounted) {
        _showInfoSnack('소스 선택을 해제하고 전체 이벤트 로그 보기로 전환했습니다.');
      }
      apiEventController.setVisibleSourceKey('');
      unawaited(_refreshApiEventsIfNeeded());
      return;
    }
    setState(() {
      selectedApiEventDetail = null;
      apiDetailErrorMessage = null;
      frameDetectionSnapshots = const [];
      frameDetectionLogModifiedAt = null;
      frameDetectionSourceKey = '';
    });
    apiEventController.setVisibleSourceKey('');
    unawaited(_refreshApiEventsIfNeeded());
  }

  String _buildSourceKey({
    required String sourceType,
    required String sourceValue,
  }) {
    final normalizedType = sourceType.trim().toLowerCase();
    final normalizedValue = sourceValue.trim().replaceAll('\\', '/').toLowerCase();
    return '$normalizedType|$normalizedValue';
  }
}

class _SourcePanelSlot {
  _SourcePanelSlot({
    required this.slotId,
    required this.sourceType,
    required this.sourceValue,
    required this.sourceKey,
    required this.originalSourceType,
    required this.originalSourceValue,
    required this.label,
    required this.controller,
  });

  final String slotId;
  final String sourceType;
  final String sourceValue;
  final String sourceKey;
  final String originalSourceType;
  final String originalSourceValue;
  final String label;
  final VideoPanelController controller;
}

class _ClipTargetBinding {
  const _ClipTargetBinding({
    required this.controller,
    required this.preserveReturnContext,
  });

  final VideoPanelController controller;
  final bool preserveReturnContext;
}
