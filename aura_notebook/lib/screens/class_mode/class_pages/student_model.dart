// lib/screens/student_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Shared student model + StudentRegistry
//
// WHY THIS EXISTS:
//   Students added in StudentsTab must appear in AttendanceTab.
//   Both tabs receive the SAME List<StudentModel> from ClassDetailPage,
//   so any add/remove in one is immediately visible in the other.
// ─────────────────────────────────────────────────────────────────────────────

enum AttendanceStatus { present, absent, late }

class StudentModel {
  final String name;
  final String roll;
  final bool   isCR;

  const StudentModel({
    required this.name,
    required this.roll,
    this.isCR = false,
  });

  StudentModel copyWith({String? name, String? roll, bool? isCR}) =>
      StudentModel(
        name: name ?? this.name,
        roll: roll ?? this.roll,
        isCR: isCR ?? this.isCR,
      );
}