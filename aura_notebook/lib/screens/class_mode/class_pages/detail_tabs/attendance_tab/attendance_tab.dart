import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../class_data.dart';
import '../../student_model.dart';

part 'attendance_tab_state.dart';
part 'attendance_tab_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AttendanceTab — receives the shared List<StudentModel> from ClassDetailPage
// so it always shows exactly the same students as the Roster tab.
// ─────────────────────────────────────────────────────────────────────────────
class AttendanceTab extends StatefulWidget {
  final ClassData          data;
  final List<StudentModel> students;   // ← shared list from ClassDetailPage

  const AttendanceTab({
    super.key,
    required this.data,
    required this.students,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}
