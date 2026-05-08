import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../services/video_service.dart';

class VideoPanelController extends ChangeNotifier {
  VideoPanelController({VideoService? service})
      : _service = service ?? VideoService() {
    _listenVideoState();
  }

  final VideoService _service;

  String videoPath = '';
  String liveSourcePath = '';
  String sourceType = '';
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  double frameRate = 30.0;
  String errorText = '';
  bool isReplayMode = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  VideoController get videoController => _service.videoController;

  bool get hasVideo => videoPath.isNotEmpty;
  bool get isStreamMode => sourceType == 'stream';
  int get currentFrameValue =>
      ((currentPosition.inMilliseconds / 1000) * frameRate).round();

  Future<void> openVideo(String path, {String nextSourceType = 'video'}) async {
    errorText = '';

    if (path.isEmpty) {
      notifyListeners();
      return;
    }

    if (nextSourceType == 'video') {
      final file = File(path);
      if (!await file.exists()) {
        errorText = '영상 파일을 찾을 수 없습니다.';
        notifyListeners();
        return;
      }
    }

    videoPath = path;
    sourceType = nextSourceType;
    if (nextSourceType == 'stream') {
      liveSourcePath = path;
      isReplayMode = false;
    }
    await _service.openVideo(path);
    notifyListeners();
  }

  Future<void> openReplayClip(String path) async {
    await openVideo(path, nextSourceType: 'video');
    isReplayMode = true;
    notifyListeners();
  }

  Future<void> returnToLive() async {
    if (liveSourcePath.isEmpty) {
      return;
    }
    await openVideo(liveSourcePath, nextSourceType: 'stream');
  }

  Future<void> togglePlay() async {
    if (!hasVideo) {
      return;
    }

    if (isPlaying) {
      await _service.pause();
    } else {
      await _service.play();
    }
  }

  Future<void> movePrevFrame() async {
    await _moveByFrame(-1);
  }

  Future<void> moveNextFrame() async {
    await _moveByFrame(1);
  }

  Future<void> moveToRatio(double ratio) async {
    if (totalDuration.inMilliseconds <= 0) {
      return;
    }

    final safeRatio = ratio.clamp(0.0, 1.0);
    final nextMs = (totalDuration.inMilliseconds * safeRatio).round();
    await _service.seek(Duration(milliseconds: nextMs));
  }

  void setFrameRate(double value) {
    if (value <= 0) {
      return;
    }
    frameRate = value;
    notifyListeners();
  }

  void disposeController() {
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_playingSub?.cancel());
    unawaited(_service.dispose());
  }

  void _listenVideoState() {
    _positionSub = _service.positionStream.listen((value) {
      currentPosition = value;
      notifyListeners();
    });

    _durationSub = _service.durationStream.listen((value) {
      totalDuration = value;
      notifyListeners();
    });

    _playingSub = _service.playingStream.listen((value) {
      isPlaying = value;
      notifyListeners();
    });
  }

  Future<void> _moveByFrame(int frameStep) async {
    if (frameRate <= 0) {
      return;
    }

    final frameMs = (1000 / frameRate).round();
    final nextMs = currentPosition.inMilliseconds + (frameMs * frameStep);
    final safeMs = nextMs < 0 ? 0 : nextMs;
    await _service.seek(Duration(milliseconds: safeMs));
  }
}
