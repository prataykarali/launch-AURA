import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aura_notebook/src/rust/api.dart';
import '../../class_data.dart';

part 'smart_briefing_card_state.dart';
part 'smart_briefing_card_ui.dart';

const _kSentinel = '\x00__THINKING__\x00';

class SmartBriefingCard extends StatefulWidget {
  final ClassData data;
  final int       topicsDone;
  final int       topicsTotal;
  final int       xp;
  final int       studentCount;

  const SmartBriefingCard({
    super.key,
    required this.data,
    required this.topicsDone,
    required this.topicsTotal,
    required this.xp,
    required this.studentCount,
  });

  @override
  State<SmartBriefingCard> createState() => _SmartBriefingCardState();
}
