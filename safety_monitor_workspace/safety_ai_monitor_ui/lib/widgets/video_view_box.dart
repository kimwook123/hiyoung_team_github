import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../controllers/video_panel_controller.dart';
import '../models/event_log_item.dart';
import '../models/video_overlay_detection.dart';
import 'video_event_overlay.dart';

// 메인 영상 표시 영역입니다.
// 현재 영상 위에 overlayItems를 얹어서 위험 이벤트를 같은 화면에서 확인할 수 있게 합니다.
class VideoViewBox extends StatelessWidget {
  const VideoViewBox({
    super.key,
    required this.controller,
    required this.overlayItems,
    required this.overlayDetections,
  });

  final VideoPanelController controller;
  final List<EventLogItem> overlayItems;
  final List<VideoOverlayDetection> overlayDetections;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: controller.hasVideo
                ? Video(
                    controller: controller.videoController,
                    controls: NoVideoControls,
                  )
                : const Center(
                    child: Text(
                      '영상을 열면 여기에 표시됩니다.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
          ),
          VideoEventOverlay(
            items: overlayItems,
            detections: overlayDetections,
            sourceWidth: controller.videoWidth.toDouble(),
            sourceHeight: controller.videoHeight.toDouble(),
          ),
        ],
      ),
    );
  }
}
