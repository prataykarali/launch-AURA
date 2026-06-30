// chat_widget.dart
// AuraChatWidget — pure orchestration: stream lifecycle, busy state, scroll.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:aura_notebook/bar/bar_multi_window_service.dart';
import 'package:aura_notebook/bar/bar_state.dart';
import 'package:aura_notebook/services/natural_context_service.dart';
import 'package:aura_notebook/services/tts_service.dart';

import '../../../notebook_page.dart';

import '../chat_constants.dart';
import '../chat_message.dart';
import '../message_chunker.dart';
import '../message_list.dart';
import '../input_bar.dart';

part 'chat_widget_state.dart';
part 'chat_widget_typewriter.dart';
part 'chat_widget_scroll.dart';

class AuraChatWidget extends StatefulWidget {
  const AuraChatWidget({super.key});

  @override
  State<AuraChatWidget> createState() => _AuraChatWidgetState();
}
