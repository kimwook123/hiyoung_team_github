import 'package:flutter/material.dart';

// 상단 입력 제어 패널입니다.
// 영상 파일 선택, 스트림 주소 입력, API 서버 사용 안내를 한 곳에 모아 둡니다.
class FileBar extends StatelessWidget {
  const FileBar({
    super.key,
    required this.videoPath,
    required this.sourceType,
    required this.sourceHint,
    required this.sourceCount,
    required this.activeSourceLabel,
    required this.hasSelectedSource,
    required this.canReturnFromReplay,
    required this.streamTextController,
    required this.onPickVideo,
    required this.onClearSelectedSource,
    required this.onOpenStream,
    required this.onReturnLive,
  });

  final String videoPath;
  final String sourceType;
  final String sourceHint;
  final int sourceCount;
  final String activeSourceLabel;
  final bool hasSelectedSource;
  final bool canReturnFromReplay;
  final TextEditingController streamTextController;
  final VoidCallback onPickVideo;
  final VoidCallback onClearSelectedSource;
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
          buttonText: '영상 추가',
          helperText: sourceHint,
          sourceCount: sourceCount,
          activeSourceLabel: activeSourceLabel,
          onPressed: onPickVideo,
          hasSelectedSource: hasSelectedSource,
          onClearSelectedSource: onClearSelectedSource,
          canReturnFromReplay: canReturnFromReplay,
          onReturnLive: onReturnLive,
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
                child: const Text('스트림 추가'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.title,
    required this.value,
    required this.buttonText,
    required this.helperText,
    required this.sourceCount,
    required this.activeSourceLabel,
    required this.onPressed,
    required this.hasSelectedSource,
    required this.onClearSelectedSource,
    required this.canReturnFromReplay,
    required this.onReturnLive,
  });

  final String title;
  final String value;
  final String buttonText;
  final String helperText;
  final int sourceCount;
  final String activeSourceLabel;
  final VoidCallback onPressed;
  final bool hasSelectedSource;
  final VoidCallback onClearSelectedSource;
  final bool canReturnFromReplay;
  final VoidCallback onReturnLive;

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
          const SizedBox(height: 4),
          Text(
            sourceCount <= 0
                ? '등록된 소스가 없습니다.'
                : '등록된 소스 $sourceCount개 / 현재 화면: $activeSourceLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: onPressed,
                child: Text(buttonText),
              ),
              if (hasSelectedSource) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onClearSelectedSource,
                  child: const Text('선택 해제'),
                ),
              ],
              if (canReturnFromReplay) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onReturnLive,
                  child: const Text('클립 닫기'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
