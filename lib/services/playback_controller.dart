import 'dart:async';
import 'package:audio_service/audio_service.dart' as svc;
import 'package:audio_session/audio_session.dart' as ases;
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;
import '../models/video_item.dart';
import '../utils.dart';
import 'audio_handler.dart';
import 'library_provider.dart';
import 'power_features.dart';
import 'settings_provider.dart';
import 'stream_service.dart';

/// App-wide player. Screen band hone par, app minimize karne par ya screen lock
/// hone par bhi player zinda rehta hai (Android foreground service + notification).
class PlaybackController extends ChangeNotifier with WidgetsBindingObserver {
  final Player player = Player();
  late final VideoController controller;
  final yte.YoutubeExplode _yt = yte.YoutubeExplode();
  final List<StreamSubscription> _subs = [];

  VideoItem? video;
  bool loading = false;
  String? error; // load fail: video ke upar Retry box
  String? playerError; // player ki chhoti error: banner
  String? notice; // jaise "1080p nahi chali, 360p par chala di"
  List<QualityOption> options = [];
  QualityOption? current;
  List<SponsorSegment> segments = [];
  bool sbEnabled = true;
  int skipped = 0;
  double speed = 1.0;
  String description = '';
  int views = 0;
  bool playing = false;
  bool buffering = false;
  bool completed = false;

  /// PlayerScreen yahan snackbar dikhane ka callback lagata hai.
  VoidCallback? onSkip;

  AppAudioHandler? _handler;
  DateTime _lastSkip = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);
  int _token = 0; // naya video khulne par purane async kaam ignore karne ke liye

  // Video decode sirf tab chalao jab player screen dikh rahi ho aur app saamne ho.
  // Background me sirf awaaz chalti hai: battery bachti hai aur Android decoder nahi rokta.
  bool _screenVisible = false;
  bool _appForeground = true;
  bool _videoOn = true;

  bool _askedNotification = false;
  bool _pausedByInterruption = false;

  PlaybackController() {
    controller = VideoController(player);
    WidgetsBinding.instance.addObserver(this);
    _subs.add(player.stream.position.listen(_onPosition));
    _subs.add(player.stream.playing.listen((p) {
      playing = p;
      _publishState();
      notifyListeners();
    }));
    _subs.add(player.stream.buffering.listen((b) {
      buffering = b;
      _publishState();
    }));
    _subs.add(player.stream.completed.listen((c) {
      completed = c;
      _publishState();
      notifyListeners();
    }));
    _subs.add(player.stream.duration.listen((d) {
      if (d > Duration.zero) {
        _publishItem(d);
        _publishState();
      }
    }));
    _subs.add(player.stream.error.listen((e) {
      if (e.isNotEmpty) {
        playerError = e;
        notifyListeners();
      }
    }));
  }

  /// Notification + lock-screen controls + audio focus. Fail ho to app bina background play ke chalti hai.
  Future<void> initBackground() async {
    try {
      _handler = await svc.AudioService.init(
        builder: () => AppAudioHandler(
          onPlay: () => player.play(),
          onPause: () => player.pause(),
          onStop: stop,
          onSeek: (d) => player.seek(d),
        ),
        config: const svc.AudioServiceConfig(
          androidNotificationChannelId: 'com.example.my_youtube_app.playback',
          androidNotificationChannelName: 'My YouTube playback',
          androidStopForegroundOnPause: false,
        ),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      _handler = null;
    }
    try {
      final session = await ases.AudioSession.instance;
      await session.configure(ases.AudioSessionConfiguration.music());
      _subs.add(session.interruptionEventStream.listen(_onInterruption));
      _subs.add(session.becomingNoisyEventStream.listen((_) => player.pause()));
    } catch (_) {}
  }

  // Call aaye ya doosra app awaaz chalaye to ruko, headphone nikal jaye to ruko.
  void _onInterruption(ases.AudioInterruptionEvent e) {
    if (e.begin) {
      if (e.type == ases.AudioInterruptionType.duck) {
        player.setVolume(30);
      } else if (playing) {
        _pausedByInterruption = true;
        player.pause();
      }
    } else {
      if (e.type == ases.AudioInterruptionType.duck) {
        player.setVolume(100);
      } else if (_pausedByInterruption) {
        _pausedByInterruption = false;
        player.play();
      }
    }
  }

  void _askNotificationPermission() {
    if (_askedNotification) return;
    _askedNotification = true;
    () async {
      try {
        await Permission.notification.request();
      } catch (_) {}
    }();
  }

  // ---- notification / media session ----

  void _publishItem([Duration? duration]) {
    final h = _handler;
    final v = video;
    if (h == null || v == null) return;
    final d = duration ?? (v.durationSec > 0 ? Duration(seconds: v.durationSec) : null);
    h.mediaItem.add(svc.MediaItem(
      id: v.id,
      title: v.title,
      artist: v.author,
      artUri: Uri.parse(v.thumb),
      duration: d,
    ));
  }

  void _publishState() {
    final h = _handler;
    if (h == null) return;
    if (video == null || error != null) {
      h.setIdle();
      return;
    }
    _lastPublish = DateTime.now();
    svc.AudioProcessingState proc;
    if (loading) {
      proc = svc.AudioProcessingState.loading;
    } else if (completed) {
      proc = svc.AudioProcessingState.completed;
    } else if (buffering) {
      proc = svc.AudioProcessingState.buffering;
    } else {
      proc = svc.AudioProcessingState.ready;
    }
    h.playbackState.add(svc.PlaybackState(
      controls: [playing ? svc.MediaControl.pause : svc.MediaControl.play, svc.MediaControl.stop],
      systemActions: const {svc.MediaAction.seek},
      androidCompactActionIndices: const [0, 1],
      processingState: proc,
      playing: playing,
      updatePosition: player.state.position,
      bufferedPosition: player.state.buffer,
      speed: speed,
    ));
  }

  // ---- video decode on/off (background me sirf awaaz) ----

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = !(state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached);
    if (fg != _appForeground) {
      _appForeground = fg;
      _applyVideoTrack();
    }
  }

  /// PlayerScreen dikhne/chhupne par bulao. notifyListeners nahi karta (dispose me safe).
  void setScreenVisible(bool v) {
    _screenVisible = v;
    _applyVideoTrack();
  }

  void _applyVideoTrack() {
    final want = _screenVisible && _appForeground;
    if (want == _videoOn) return;
    _videoOn = want;
    _setVideoOutput(want);
  }

  /// mpv ki "vid" property: 'no' = video decode band (sirf awaaz), 'auto' = wapas chalu.
  Future<void> _setVideoOutput(bool on) async {
    try {
      await (player.platform as dynamic).setProperty('vid', on ? 'auto' : 'no');
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    _yt.close();
    super.dispose();
  }

  // ---- playback ----

  /// Video kholo. Wahi video pehle se chal rahi ho to dobara load nahi karta.
  Future<void> open(VideoItem v, SettingsProvider settings, LibraryProvider library) async {
    if (video?.id == v.id && (loading || (error == null && current != null))) return;

    final token = ++_token;
    video = v;
    loading = true;
    error = null;
    playerError = null;
    notice = null;
    options = [];
    current = null;
    segments = [];
    skipped = 0;
    description = '';
    views = 0;
    buffering = false;
    completed = false;
    sbEnabled = settings.sponsorBlock;
    library.addHistory(v);
    _askNotificationPermission();
    _publishItem();
    _publishState();
    notifyListeners();

    _fetchDetails(v.id, token);
    try {
      final opts = await StreamService.load(_yt, v.id);
      if (token != _token) return;
      options = opts;
      final opt = StreamService.pick(opts, settings.defaultQuality);
      final ok = await _play(opt, token);
      if (token != _token) return;
      if (!ok && !opt.isMuxed) {
        // HD (video + awaaz alag) nahi chali: bharose wali stream par chala do.
        final fb = StreamService.bestMuxed(opts);
        if (fb != null) {
          notice = '${opt.label} nahi chali, ${fb.label} par chala di.';
          notifyListeners();
          await _play(fb, token);
          if (token != _token) return;
        }
      }
      if (sbEnabled) _loadSegments(v.id, token);
      loading = false;
      _publishState();
      notifyListeners();
    } catch (e) {
      if (token != _token) return;
      loading = false;
      error = friendlyError(e);
      _publishState();
      notifyListeners();
    }
  }

  Future<void> _fetchDetails(String id, int token) async {
    try {
      final v = await _yt.videos.get(id);
      if (token != _token) return;
      description = v.description;
      views = v.engagement.viewCount;
      notifyListeners();
    } catch (_) {}
  }

  void _loadSegments(String id, int token) {
    PowerFeatures.getSponsorSegments(id).then((s) {
      if (token != _token) return;
      segments = s;
      notifyListeners();
    });
  }

  /// true = media sach me load ho gaya (duration mili). false = 12 second me load nahi hua.
  Future<bool> _play(QualityOption opt, int token, {Duration resume = Duration.zero}) async {
    current = opt;
    final loaded = player.stream.duration
        .firstWhere((d) => d > Duration.zero)
        .then<bool>((_) => true)
        .catchError((_) => false);
    await player.open(Media(opt.url), play: false);
    if (token != _token) return false;
    var started = false;
    try {
      started = await loaded.timeout(const Duration(seconds: 12));
    } catch (_) {}
    if (token != _token) return false;
    if (started && opt.audioUrl != null) {
      try {
        await player.setAudioTrack(AudioTrack.uri(opt.audioUrl!));
      } catch (_) {}
    }
    if (token != _token) return false;
    if (started && resume > Duration.zero) {
      try {
        await player.seek(resume);
      } catch (_) {}
    }
    try {
      await player.setRate(speed);
    } catch (_) {}
    if (!_videoOn) await _setVideoOutput(false);
    if (token != _token) return false;
    await player.play();
    return started;
  }

  Future<void> switchQuality(QualityOption o) async {
    final token = _token;
    final pos = player.state.position;
    loading = true;
    error = null;
    playerError = null;
    notice = null;
    _publishState();
    notifyListeners();
    try {
      await _play(o, token, resume: pos);
    } catch (e) {
      if (token == _token) error = friendlyError(e);
    }
    if (token == _token) {
      loading = false;
      _publishState();
      notifyListeners();
    }
  }

  Future<void> setSpeed(double s) async {
    speed = s;
    notifyListeners();
    await player.setRate(s);
    _publishState();
  }

  void toggleSponsor(bool v) {
    sbEnabled = v;
    if (v && segments.isEmpty && video != null) {
      _loadSegments(video!.id, _token);
    }
    notifyListeners();
  }

  Future<void> togglePlay() async {
    await player.playOrPause();
  }

  Future<void> stop() async {
    _token++;
    video = null;
    current = null;
    options = [];
    segments = [];
    loading = false;
    error = null;
    playerError = null;
    notice = null;
    notifyListeners();
    try {
      await player.stop();
    } catch (_) {}
    _handler?.setIdle();
  }

  void _onPosition(Duration p) {
    final now = DateTime.now();
    if (video != null && !loading && now.difference(_lastPublish) > const Duration(seconds: 5)) {
      _publishState();
    }
    if (!sbEnabled || segments.isEmpty) return;
    if (now.difference(_lastSkip) < const Duration(seconds: 2)) return;
    final pos = p.inMilliseconds / 1000.0;
    for (final s in segments) {
      if (pos >= s.start && pos < s.end - 0.3) {
        _lastSkip = now;
        player.seek(Duration(milliseconds: (s.end * 1000).round()));
        skipped++;
        notifyListeners();
        onSkip?.call();
        break;
      }
    }
  }
}
