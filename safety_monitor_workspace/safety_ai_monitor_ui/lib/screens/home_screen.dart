import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/event_log_controller.dart';
import '../controllers/video_panel_controller.dart';
import '../models/event_log_item.dart';
import '../services/app_link_service.dart';
import '../widgets/event_log_box.dart';
import '../widgets/file_bar.dart';
import '../widgets/video_control_bar.dart';
import '../widgets/video_view_box.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final VideoPanelController videoController;
  late final EventLogController logController;
  late final AppLinkService appLinkService;
  final TextEditingController streamTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    videoController = VideoPanelController();
    logController = EventLogController();
    appLinkService = AppLinkService();

    // GUI가 열릴 때 이전 선택 상태는 비운다
    appLinkService.clearSourceState();
  }

  @override
  void dispose() {
    videoController.disposeController();
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
                              [videoController, logController],
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
                    child: AnimatedBuilder(
                      animation: logController,
                      builder: (context, _) {
                        return EventLogBox(
                          controller: logController,
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
    return logController.getItemsForFrame(videoController.currentFrameValue);
  }

  Future<void> _onTapEventItem(EventLogItem item) async {
    logController.selectItem(item);

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
