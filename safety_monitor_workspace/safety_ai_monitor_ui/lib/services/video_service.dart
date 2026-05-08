import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoService {
  VideoService() : player = Player() {
    videoController = VideoController(player);
  }

  final Player player;
  late final VideoController videoController;

  Stream<Duration> get positionStream => player.stream.position;
  Stream<Duration> get durationStream => player.stream.duration;
  Stream<bool> get playingStream => player.stream.playing;

  Future<void> openVideo(String source) async {
    // 로컬 파일이나 RTSP/HTTP 주소를 연다
    await player.open(Media(source));
  }

  Future<void> play() async {
    await player.play();
  }

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> dispose() async {
    await player.dispose();
  }
}
