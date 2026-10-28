import 'package:audio_service/audio_service.dart';

/// Android ka media notification, lock-screen controls aur foreground service.
/// Asli player PlaybackController me hai, yeh sirf bridge hai.
class AppAudioHandler extends BaseAudioHandler {
  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function() onStop;
  final Future<void> Function(Duration) onSeek;

  AppAudioHandler({
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onSeek,
  });

  @override
  Future<void> play() => onPlay();

  @override
  Future<void> pause() => onPause();

  @override
  Future<void> seek(Duration position) => onSeek(position);

  @override
  Future<void> stop() async {
    await onStop();
    await super.stop();
  }

  /// Kuch nahi chal raha: notification hatao aur service band karo.
  void setIdle() {
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle, playing: false));
    mediaItem.add(null);
  }
}
