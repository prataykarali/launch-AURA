import 'package:flutter/material.dart';

class Doubt {
  final String question;
  final String subject;
  final DateTime timestamp;
  final ValueNotifier<String> streamText = ValueNotifier('');

  bool isAnswered = false;
  bool escalated = false;
  bool markedHelpful = false;

  Doubt({
    required this.question,
    required this.subject,
    required this.timestamp,
  });
}
