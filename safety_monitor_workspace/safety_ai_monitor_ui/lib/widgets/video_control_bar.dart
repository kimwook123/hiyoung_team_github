import 'package:flutter/material.dart';

import '../controllers/video_panel_controller.dart';

// 재생, 프레임 이동, 탐색 슬라이더를 묶은 하단 제어 바입니다.
class VideoControlBar extends StatelessWidget {
  const VideoControlBar({super.key, required this.controller});

  final VideoPanelController controller;

  @override
  Widget build(BuildContext context) {
    // 현재 시간을 비율로 바꿔 Slider와 연결합니다.
    final totalMs = controller.totalDuration.inMilliseconds;
    final currentMs = controller.currentPosition.inMilliseconds;
    final sliderValue = totalMs <= 0 ? 0.0 : currentMs / totalMs;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171A20),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Slider(
            value: sliderValue.clamp(0.0, 1.0),
            onChanged: controller.hasVideo
                ? (value) => controller.moveToRatio(value)
                : null,
          ),
          Row(
            children: [
              IconButton(
                onPressed: controller.hasVideo
                    ? controller.movePrevFrame
                    : null,
                tooltip: '이전 프레임',
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                onPressed: controller.hasVideo ? controller.togglePlay : null,
                tooltip: '재생 또는 일시정지',
                icon: Icon(
                  controller.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
              IconButton(
                onPressed: controller.hasVideo
                    ? controller.moveNextFrame
                    : null,
                tooltip: '다음 프레임',
                icon: const Icon(Icons.skip_next),
              ),
              const SizedBox(width: 12),
              Text(
                '${_formatTime(controller.currentPosition)} / '
                '${_formatTime(controller.totalDuration)}',
              ),
              const Spacer(),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: controller.frameRate.toStringAsFixed(1),
                  decoration: const InputDecoration(
                    labelText: 'FPS',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (value) {
                    final nextValue = double.tryParse(value);
                    if (nextValue != null) {
                      controller.setFrameRate(nextValue);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    final milliseconds = value.inMilliseconds.remainder(1000);

    if (hours > 0) {
      return '$hours:${_two(minutes)}:${_two(seconds)}.${_three(milliseconds)}';
    }

    return '${_two(minutes)}:${_two(seconds)}.${_three(milliseconds)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
  String _three(int value) => value.toString().padLeft(3, '0');
}
