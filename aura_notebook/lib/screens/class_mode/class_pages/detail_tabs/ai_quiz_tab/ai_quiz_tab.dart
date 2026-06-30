import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';
import '../../class_data.dart';

part 'mcq_question.dart';
part 'ai_quiz_tab_state.dart';
part 'intro_screen.dart';
part 'generating_screen.dart';
part 'question_screen.dart';
part 'results_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiQuizTab — AI-generated MCQ quiz based on completed syllabus topics.
// • Calls auraChat() to generate 5 questions in a structured format
// • Parses the response into McqQuestion objects in Dart
// • Interactive quiz UI with instant feedback and XP reward
// ─────────────────────────────────────────────────────────────────────────────
class AiQuizTab extends StatefulWidget {
  final ClassData data;
  final List<dynamic> completedTopics; // Or your Topic model
  final int topicsDone;     // Added this
  final int topicsTotal;    // Added this
  final int studentCount;   // Added this
  final Function(int) onXpEarned;

  const AiQuizTab({
    super.key,
    required this.data,
    required this.completedTopics,
    required this.onXpEarned,
    this.topicsDone = 0,    // Default values to prevent errors
    this.topicsTotal = 0,
    this.studentCount = 0,
  });

  @override
  State<AiQuizTab> createState() => _AiQuizTabState();
}
