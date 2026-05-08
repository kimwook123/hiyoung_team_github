import 'dart:io';

import 'package:flutter/material.dart';

class FileBar extends StatelessWidget {
  const FileBar({
    super.key,
    required this.videoPath,
    required this.sourceType,
    required this.logPath,
    required this.isReplayMode,
    required this.streamTextController,
    required this.onPickVideo,
    required this.onOpenStream,
    required this.onReturnLive,
  });

  final String videoPath;
  final String sourceType;
  final String logPath;
  final bool isReplayMode;
  final TextEditingController streamTextController;
  final VoidCallback onPickVideo;
  final VoidCallback onOpenStream;
  final VoidCallback onReturnLive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PathCard(
          title: sourceType == 'stream' ? '현재 스트림 주소' : '영상 파일',
          value: videoPath.isEmpty ? '선택되지 않음' : videoPath,
          buttonText: '영상 열기',
          helperText: _buildHelperText(),
          onPressed: onPickVideo,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: streamTextController,
                  decoration: const InputDecoration(
                    labelText: 'CCTV / RTSP / HTTP 주소',
                    hintText: 'rtsp://127.0.0.1:8554/live',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onOpenStream,
                child: const Text('스트림 열기'),
              ),
              if (isReplayMode) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onReturnLive,
                  child: const Text('라이브 복귀'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _buildHelperText() {
    if (logPath.isEmpty) {
      return '로그 파일은 분석 시작 후 자동으로 연결됩니다.';
    }

    final fileName = File(logPath).uri.pathSegments.isEmpty
        ? logPath
        : File(logPath).uri.pathSegments.last;
    return '로그: $fileName';
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.title,
    required this.value,
    required this.buttonText,
    required this.helperText,
    required this.onPressed,
  });

  final String title;
  final String value;
  final String buttonText;
  final String helperText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
