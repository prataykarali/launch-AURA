/// AURA Character State Bus — seam for a future 2D drive-layer.
///
/// Single responsibility: carry "how the persona currently feels" from
/// core assistant state (TTS playing, wake-word listening, LLM emotion)
/// to any subscriber (avatar widget, overlay, logging) without anyone
/// touching chat internals.
///
/// Design contract:
///   - Pure publish/subscribe. No business logic, no LLM knowledge.
///   - Subscribers must tolerate empty/zero states — the bus starts cold.
///   - Emitters must never block. All emission paths are sync + lossless.
///
/// Today only the trivial persona defaults are emitted. The 2D drive-layer
/// (e.g. a Rive-backed widget in `lib/character/`) will subscribe to
/// [CharacterBus.stream] later; we do NOT add Rive now (see
/// launch_freeze plan: adding it would force asset/runtime changes on
/// every platform and breach "smallest change" rule).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// What the character should be doing right now.
///
/// Chosen to be modality-agnostic. A 2D sprite, Live2D model, or a simple
/// on-screen indicator can all map these unambiguously.
enum CharacterPose {
  /// Default idle. Rendered when nothing else is happening.
  idle,

  /// Assistant is listening (wake-word active or dictation in progress).
  listening,

  /// Assistant is thinking (LLM turn in flight, awaiting first token).
  thinking,

  /// Assistant is speaking (TTS engine actively playing audio).
  speaking,
}

/// Snapshot carrying pose + optional coarse emotion tag.
///
/// `emotionLabel` is deliberately free-form so persona tags from
/// `chat/turn.rs` ("warm", "concerned", "playful") can flow through later
/// without schema churn.
@immutable
class CharacterState {
  const CharacterState({required this.pose, this.emotionLabel});

  final CharacterPose pose;
  final String? emotionLabel;

  CharacterState copyWith({
    CharacterPose? pose,
    String? emotionLabel,
  }) =>
      CharacterState(
        pose: pose ?? this.pose,
        emotionLabel: emotionLabel ?? this.emotionLabel,
      );

  @override
  bool operator ==(Object other) =>
      other is CharacterState &&
      other.pose == pose &&
      other.emotionLabel == emotionLabel;

  @override
  int get hashCode => Object.hash(pose, emotionLabel);

  @override
  String toString() => 'CharacterState(pose=$pose, emotion=$emotionLabel)';
}

/// Process-wide bus. Not a singleton because tests need their own.
final class CharacterBus {
  CharacterBus._();

  static final CharacterBus instance = CharacterBus._();

  final StreamController<CharacterState> _controller =
      StreamController<CharacterState>.broadcast(sync: true);

  CharacterState _current = const CharacterState(pose: CharacterPose.idle);

  /// Latest snapshot for late subscribers / pull-based widgets.
  CharacterState get current => _current;

  /// Stream of state transitions. Never closes while the app is alive.
  Stream<CharacterState> get stream => _controller.stream;

  /// Emit a new pose, preserving the current emotion label.
  void setPose(CharacterPose pose) => _emit(_current.copyWith(pose: pose));

  /// Emit a coarse emotion label (e.g. from LLM classification),
  /// preserving the current pose.
  void setEmotion(String? label) =>
      _emit(_current.copyWith(emotionLabel: label));

  /// Emit a fully-formed state. Internal emitters prefer
  /// [setPose] / [setEmotion] to avoid partial-state churn.
  void emit(CharacterState state) => _emit(state);

  void _emit(CharacterState next) {
    if (next == _current) return; // dedupe no-op transitions
    _current = next;
    _controller.add(next);
    if (kDebugMode) {
      debugPrint('[CHAR_BUS] $next');
    }
  }
}
