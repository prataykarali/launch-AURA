part of 'students_tab.dart';

class _SF extends StatelessWidget {
  final TextEditingController ctrl; final String label, hint;
  const _SF({required this.ctrl, required this.label, required this.hint});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 12),
      hintStyle:  TextStyle(color: Colors.white.withOpacity(0.18), fontSize: 13),
      filled: true, fillColor: const Color(0xFF1E1E32),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
  );
}
