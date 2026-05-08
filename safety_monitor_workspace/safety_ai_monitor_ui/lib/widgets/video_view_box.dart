import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../controllers/video_panel_controller.dart';
import '../models/event_log_item.dart';
import 'video_event_overlay.dart';

class VideoViewBox extends StatelessWidget {
  const VideoViewBox({
    super.key,
    required this.controller,
    required this.overlayItems,
  });

  final VideoPanelController controller;
  final List<EventLogItem> overlayItems;

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
          VideoEventOverlay(items: overlayItems),
        ],
      ),
    );
  }
}
