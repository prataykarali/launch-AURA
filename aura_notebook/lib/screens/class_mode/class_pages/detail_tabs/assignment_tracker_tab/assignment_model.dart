part of '../assignment_tracker_tab.dart';

class _Assignment {
  final String   title, description;
  final int      marks;
  final DateTime dueDate;
  bool           submitted = false;

  _Assignment({required this.title, required this.description,
    required this.marks, required this.dueDate});

  int  get daysLeft  => dueDate.difference(DateTime.now()).inDays;
  bool get isOverdue => daysLeft < 0;
}
