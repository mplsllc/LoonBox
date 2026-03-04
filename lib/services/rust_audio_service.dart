import 'dart:async';

import '../features/player/domain/player_state.dart' as domain;
import 'audio_service.dart';
import '../src/rust/api.dart' as rust;
import '../src/rust/frb_generated.dart';

/// Concrete [AudioService] implementation backed by the Rust loonbox_audio engine
/// via flutter_rust_bridge.
class RustAudioService implements AudioService {
  RustAudioService._();

  static Future<RustAudioService> create() async {
    await RustLib.init();
    final service = RustAudioService._();
    service._startPolling();
    return service;
  }

  final _eventController = StreamController<domain.PlayerEvent>.broadcast();
  Timer? _pollTimer;

  void _startPolling() {
    // Poll Rust engine for events every 50ms
    _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
      try {
        final events = await rust.playerPollEvents();
        for (final event in events) {
          _eventController.add(_convertEvent(event));
        }
      } catch (_) {
        // Engine not yet initialized or other transient error — skip
      }
    });
  }

  domain.PlayerEvent _convertEvent(rust.PlayerEvent event) {
    return switch (event) {
      rust.PlayerEvent_Position(:final field0) =>
        domain.PositionEvent(field0.toInt()),
      rust.PlayerEvent_StateChanged(:final field0) =>
        domain.StateChangedEvent(_convertState(field0)),
      rust.PlayerEvent_TrackChanged(:final field0) =>
        domain.TrackChangedEvent(_convertTrackInfo(field0)),
      rust.PlayerEvent_Error(:final field0) =>
        domain.PlayerErrorEvent(field0),
      rust.PlayerEvent_BufferProgress(:final field0) =>
        domain.BufferProgressEvent(field0),
    };
  }

  domain.PlaybackState _convertState(rust.PlayerState state) {
    return switch (state) {
      rust.PlayerState_Stopped() => domain.PlaybackState.stopped,
      rust.PlayerState_Loading() => domain.PlaybackState.loading,
      rust.PlayerState_Playing() => domain.PlaybackState.playing,
      rust.PlayerState_Paused() => domain.PlaybackState.paused,
      rust.PlayerState_Error() => domain.PlaybackState.error,
    };
  }

  domain.TrackInfo _convertTrackInfo(rust.TrackInfo info) {
    return domain.TrackInfo(
      path: info.path,
      durationMs: info.durationMs.toInt(),
      sampleRate: info.sampleRate,
      channels: info.channels,
      bitDepth: info.bitDepth,
      codec: info.codec,
    );
  }

  @override
  Future<domain.TrackInfo> load(String path) async {
    final info = await rust.playerLoad(path: path);
    return _convertTrackInfo(info);
  }

  @override
  Future<void> play() => rust.playerPlay();

  @override
  Future<void> pause() => rust.playerPause();

  @override
  Future<void> stop() => rust.playerStop();

  @override
  Future<void> seek(int positionMs) =>
      rust.playerSeek(positionMs: BigInt.from(positionMs));

  @override
  Future<void> setVolume(double volume) =>
      rust.playerSetVolume(volume: volume);

  @override
  Future<int> getPosition() async {
    final pos = await rust.playerGetPosition();
    return pos.toInt();
  }

  @override
  Future<domain.PlaybackState> getState() async {
    final state = await rust.playerGetState();
    return _convertState(state);
  }

  @override
  Future<void> setEq(List<double> bands) =>
      rust.playerSetEq(bands: bands);

  @override
  Future<void> queueSet(List<String> paths, int startIndex) =>
      rust.queueSet(paths: paths, startIndex: startIndex);

  @override
  Future<void> queueNext() => rust.queueNext();

  @override
  Future<void> queuePrevious() => rust.queuePrevious();

  @override
  Future<void> queueShuffle(bool enabled) =>
      rust.queueShuffle(enabled: enabled);

  @override
  Future<void> queueRepeat(domain.RepeatMode mode) {
    final rustMode = switch (mode) {
      domain.RepeatMode.off => rust.RepeatMode.off,
      domain.RepeatMode.one => rust.RepeatMode.one,
      domain.RepeatMode.all => rust.RepeatMode.all,
    };
    return rust.queueRepeat(mode: rustMode);
  }

  @override
  Future<void> setCrossfade(int durationMs) =>
      rust.playerSetCrossfade(durationMs: durationMs);

  @override
  Future<void> setGapless(bool enabled) =>
      rust.playerSetGapless(enabled: enabled);

  @override
  Stream<domain.PlayerEvent> get eventStream => _eventController.stream;

  void dispose() {
    _pollTimer?.cancel();
    _eventController.close();
  }
}
