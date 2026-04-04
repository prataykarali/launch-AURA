import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Shared data model for a class. Used by ClassScreen, ClassCard, ClassDetailPage.
// ─────────────────────────────────────────────────────────────────────────────
class ClassData {
  final String   name, section, subject, teacher;
  final int      students;
  final Color    color, accent;
  final IconData icon;

  const ClassData({
    required this.name,
    required this.section,
    required this.subject,
    required this.teacher,
    required this.students,
    required this.color,
    required this.accent,
    required this.icon,
  });
}