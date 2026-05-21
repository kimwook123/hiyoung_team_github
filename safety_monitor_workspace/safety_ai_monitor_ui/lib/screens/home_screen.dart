import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/api_event_controller.dart';
import '../controllers/api_event_feed_source.dart';
import '../controllers/video_panel_controller.dart';
import '../models/api_event_item.dart';
import '../models/event_log_item.dart';
import '../models/frame_detection_snapshot.dart';
import '../models/source_slot_state.dart';
import '../models/source_runtime_status.dart';
import '../models/video_overlay_detection.dart';
import '../services/app_link_service.dart';
import '../services/event_api_service.dart';
import '../services/input_source_resolver_service.dart';
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
  static const String _apiServerBaseUrl = 'http://127.0.0.1:8000';
  static const Duration _apiAutoRefreshInterval = Duration(seconds: 3);
  late final VideoPanelController _emptyVideoController;
  late final ApiEventController apiEventController;
  late final ApiEventFeedSource apiEventFeed;
  late final AppLinkService appLinkService;
  late final EventApiService eventApiService;
  late final InputSourceResolverService inputSourceResolverService;
  final ScrollController pageScrollController = ScrollController();
  final ScrollController rightPanelScrollController = ScrollController();
  final TextEditingController streamTextController = TextEditingController();
  final List<_SourcePanelSlot> _sourceSlots = [];
  String _activeSlotId = '';
  ApiEventItem? selectedApiEventDetail;
  bool isLoadingApiDetail = false;
  String? apiDetailErrorMessage;
  Timer? apiAutoRefreshTimer;
  Timer? frameDetectionRefreshTimer;
  Timer? bridgeSyncTimer;
  DateTime? frameDetectionLogModifiedAt;
  String frameDetectionSourceKey = '';
  List<FrameDetectionSnapshot> frameDetectionSnapshots = const [];
  Map<String, SourceRuntimeStatus> sourceStatusesByKey = const {};
  String lastFrameDetectionRequestSourceKey = '';
  double lastFrameDetectionRequestSeconds = -1;
  String lastFrameDetectionStatusUpdatedAt = '';

  @override
  void initState() {
    super.initState();
    _emptyVideoController = VideoPanelController();
    apiEventController = ApiEventController();
    apiEventFeed = ApiEventFeedSource(apiEventController);
    appLinkService = AppLinkService();
    eventApiService = EventApiService();
    inputSourceResolverService = InputSourceResolverService();

    // GUI가 열릴 때 이전 선택 상태는 비운다
    appLinkService.clearSourceState();
    unawaited(apiEventController.checkHealth());
    unawaited(_refreshApiEventsIfNeeded());
    _startApiAutoRefresh();
    _startFrameDetectionRefresh();
    _startBridgeSync();
    unawaited(_refreshSourceStatuses());
  }

  @override
  void dispose() {
    apiAutoRefreshTimer?.cancel();
    frameDetectionRefreshTimer?.cancel();
    bridgeSyncTimer?.cancel();
    for (final slot in _sourceSlots) {
      slot.controller.disposeController();
    }
    _emptyVideoController.disposeController();
    apiEventFeed.dispose();
    pageScrollController.dispose();
    rightPanelScrollController.dispose();
    streamTextController.dispose();
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
                          returnButtonText: videoController.replayReturnButtonText,
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

    await _resetAnalysisState(
      sourceType: 'video',
      sourceValue: file.path,
    );
    final slot = await _addOrActivateSourceSlot(
      sourceType: 'video',
      sourceValue: file.path,
      openPath: file.path,
    );
    await _syncFrameRateFromStatus(
      sourceType: 'video',
      sourceValue: file.path,
      controller: slot.controller,
    );
    unawaited(_refreshApiEventsIfNeeded());
  }

  Future<void> _openStream() async {
    final streamUrl = streamTextController.text.trim();
    if (streamUrl.isEmpty) {
      return;
    }

    final resolvedSource = await inputSourceResolverService.resolve(
      sourceType: 'stream',
      sourceValue: streamUrl,
    );

    final existingSlot = _findSourceSlot(
      sourceType: resolvedSource.sourceType,
      sourceValue: resolvedSource.sourceValue,
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

    await _resetAnalysisState(
      sourceType: resolvedSource.sourceType,
      sourceValue: resolvedSource.sourceValue,
    );
    final slot = await _addOrActivateSourceSlot(
      sourceType: resolvedSource.sourceType,
      sourceValue: resolvedSource.sourceValue,
      openPath: resolvedSource.sourceValue,
      nextSourceType: resolvedSource.sourceType,
    );
    await _syncFrameRateFromStatus(
      sourceType: resolvedSource.sourceType,
      sourceValue: resolvedSource.sourceValue,
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
    if (eventKey.isNotEmpty && eventKey != '-') {
      setState(() {
        isLoadingApiDetail = true;
        apiDetailErrorMessage = null;
        selectedApiEventDetail = null;
      });

      try {
        detail = await apiEventController.loadEventDetail(eventKey);
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

    final sourceItem =
        detail ?? apiEventController.findItemByEventKey(item.eventKeyText);
    if (sourceItem != null) {
      final activated = await _ensureSlotForEventSource(sourceItem);
      if (!activated &&
          selectedSourceKey.isNotEmpty &&
          selectedSourceKey.trim() != sourceItem.sourceKey.trim()) {
        if (mounted) {
          _showInfoSnack('이 이벤트의 원본 소스가 현재 화면에 없어 자동 이동하지 않았습니다.');
        }
        return;
      }
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

  Future<void> _resetAnalysisState({
    required String sourceType,
    required String sourceValue,
  }) async {
    await appLinkService.clearAnalysisArtifactsForSource(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );

    final sourceKey = appLinkService.buildSourceKey(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );
    final sourceSlug = appLinkService.buildSourceSlug(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );
    final resetOk = await apiEventController.resetServerData(
      sourceKey: sourceKey,
      sourceSlug: sourceSlug,
    );
    if (!resetOk && mounted) {
      setState(() {
        apiDetailErrorMessage = '서버 초기화에 실패해 이전 이벤트가 남아 있을 수 있습니다.';
        selectedApiEventDetail = null;
      });
    } else if (mounted) {
      setState(() {
        apiDetailErrorMessage = null;
        selectedApiEventDetail = null;
      });
    }

    apiEventFeed.clearSelection();
    apiEventController.items = apiEventController.items
        .where((item) => item.sourceKey.trim() != sourceKey)
        .toList(growable: false);
    apiEventController.notifyListeners();
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

  void _startBridgeSync() {
    bridgeSyncTimer?.cancel();
    bridgeSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshSourceStatuses());
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
    final movedEnough = lastFrameDetectionRequestSourceKey != sourceKey ||
        (currentOverlaySeconds - lastFrameDetectionRequestSeconds).abs() >=
            (frameIntervalSeconds * 0.5);
    final statusChanged = (runtimeStatus?.updatedAt ?? '') !=
        lastFrameDetectionStatusUpdatedAt;
    if (!movedEnough && !statusChanged) {
      return;
    }

    final toleranceSeconds = math.max(
      0.08,
      frameIntervalSeconds * 1.5,
    );
    final snapshot = await eventApiService.fetchCurrentFrameDetection(
      sourceKey: sourceKey,
      sourceTimeSeconds: currentOverlaySeconds,
      toleranceSeconds: toleranceSeconds,
    );
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

    final toleranceSeconds = math.max(
      0.08,
      (videoController.frameRate <= 0 ? 1 / 30 : 1 / videoController.frameRate) * 1.5,
    );
    final snapshot = await eventApiService.fetchCurrentFrameDetection(
      sourceKey: normalizedSourceKey,
      sourceTimeSeconds: videoController.currentOverlaySeconds,
      toleranceSeconds: toleranceSeconds,
    );
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

  Future<_SourcePanelSlot> _addOrActivateSourceSlot({
    required String sourceType,
    required String sourceValue,
    required String openPath,
    String? nextSourceType,
  }) async {
    final sourceKey = appLinkService.buildSourceKey(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );
    for (final slot in _sourceSlots) {
      if (slot.sourceKey != sourceKey) {
        continue;
      }
      await _setActiveSlot(slot.slotId);
      apiEventController.setVisibleSourceKey(sourceKey);
      await _writeAllSourcesState();
      unawaited(_refreshFrameDetectionsIfNeeded());
      return slot;
    }

    final slot = _SourcePanelSlot(
      slotId: 'slot_${DateTime.now().microsecondsSinceEpoch}',
      sourceType: sourceType,
      sourceValue: sourceValue,
      sourceKey: sourceKey,
      label: _buildSlotLabel(sourceType: sourceType, sourceValue: sourceValue),
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
    await _writeAllSourcesState();
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
    if (_sourceSlots.isEmpty) {
      await appLinkService.clearSourceState();
    } else {
      await _writeAllSourcesState();
      await _syncActiveSlotFrameRateIfNeeded();
    }
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
    unawaited(_writeAllSourcesState());
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

  Future<void> _writeAllSourcesState() async {
    final slots = _sourceSlots
        .map(
          (slot) => SourceSlotState(
            slotId: slot.slotId,
            sourceType: slot.sourceType,
            sourceValue: slot.sourceValue,
            sessionId: slot.slotId,
          ),
        )
        .toList(growable: false);
    await appLinkService.writeSourceSelection(
      slots: slots,
      activeSlotId: _activeSlotId,
    );
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
    final sourceKey = appLinkService.buildSourceKey(
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

  bool _isSameSourceValue(String left, String right) {
    final normalizedLeft = left.trim().replaceAll('\\', '/').toLowerCase();
    final normalizedRight = right.trim().replaceAll('\\', '/').toLowerCase();
    return normalizedLeft == normalizedRight;
  }

  String _buildSourceHint() {
    if (selectedSourceKey.isEmpty) {
      return '소스를 추가하고 칩을 눌러 화면을 전환할 수 있습니다. 선택된 소스가 없으면 전체 이벤트 로그를 표시합니다.';
    }

    return '현재 화면의 소스 로그와 객체 박스만 표시합니다.';
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
    final nextSourceKey = appLinkService.buildSourceKey(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );
    for (final slot in _sourceSlots) {
      if (slot.sourceKey == nextSourceKey) {
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

  String _describeSlotStatus(_SourcePanelSlot slot) {
    final sourceKey = slot.sourceKey.trim();
    if (slot.controller.errorText.trim().isNotEmpty) {
      return '오류';
    }
    if (slot.controller.isReplayMode) {
      return '클립 재생';
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
      case '클립 재생':
        return Colors.deepPurpleAccent;
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
      await _writeAllSourcesState();
      if (mounted) {
        _showInfoSnack('소스 선택을 해제하고 전체 이벤트 로그 보기로 전환했습니다.');
      }
      apiEventController.setVisibleSourceKey('');
      return;
    }

    await appLinkService.clearSourceState();
    setState(() {
      selectedApiEventDetail = null;
      apiDetailErrorMessage = null;
      frameDetectionSnapshots = const [];
      frameDetectionLogModifiedAt = null;
      frameDetectionSourceKey = '';
    });
    apiEventController.setVisibleSourceKey('');
  }
}

class _SourcePanelSlot {
  _SourcePanelSlot({
    required this.slotId,
    required this.sourceType,
    required this.sourceValue,
    required this.sourceKey,
    required this.label,
    required this.controller,
  });

  final String slotId;
  final String sourceType;
  final String sourceValue;
  final String sourceKey;
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
