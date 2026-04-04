import 'package:flutter/material.dart';
import '../screens/class_data.dart';

class AddClassSheet extends StatefulWidget {
  final void Function(ClassData) onSubmit;
  const AddClassSheet({super.key, required this.onSubmit});
  @override
  State<AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<AddClassSheet> {
  final _nameCtrl    = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  static const _colors = [
    Color(0xFF1565C0), Color(0xFF00695C), Color(0xFF6A1B9A),
    Color(0xFFB71C1C), Color(0xFFE65100), Color(0xFF006064),
  ];
  static const _accents = [
    Color(0xFF64B5F6), Color(0xFF4DD0C4), Color(0xFFCE93D8),
    Color(0xFFEF9A9A), Color(0xFFFFCC80), Color(0xFF80DEEA),
  ];
  static const _icons = [
    Icons.calculate_rounded,   Icons.science_rounded,
    Icons.brush_rounded,       Icons.menu_book_rounded,
    Icons.music_note_rounded,  Icons.sports_soccer_rounded,
  ];

  int _idx = 0;

  @override
  void dispose() {
    _nameCtrl.dispose(); _sectionCtrl.dispose();
    _subjectCtrl.dispose(); _teacherCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(ClassData(
      name:     _nameCtrl.text.trim(),
      section:  _sectionCtrl.text.trim(),
      subject:  _subjectCtrl.text.trim(),
      teacher:  _teacherCtrl.text.trim(),
      students: 0,
      color:    _colors[_idx],
      accent:   _accents[_idx],
      icon:     _icons[_idx],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF12121F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top:   BorderSide(color: Color(0x335C6BC0)),
          left:  BorderSide(color: Color(0x225C6BC0)),
          right: BorderSide(color: Color(0x225C6BC0)),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 38, height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2)),
                )),
                const Text('Create a Class',
                    style: TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),

                // Theme picker
                Text('THEME', style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.3), letterSpacing: 1.6)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _colors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final sel = i == _idx;
                      return GestureDetector(
                        onTap: () => setState(() => _idx = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: sel ? 52 : 42, height: sel ? 52 : 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_colors[i], _accents[i]],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: sel
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                            boxShadow: sel ? [BoxShadow(
                              color: _colors[i].withOpacity(0.5),
                              blurRadius: 10,
                            )] : null,
                          ),
                          child: Icon(_icons[i],
                              color: sel ? Colors.white : Colors.white54,
                              size: sel ? 22 : 18),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                _F(ctrl: _nameCtrl,    label: 'Class Name',   hint: 'e.g. Advanced Mathematics', req: true),
                const SizedBox(height: 12),
                _F(ctrl: _sectionCtrl, label: 'Section',      hint: 'e.g. Grade 10 · Section A'),
                const SizedBox(height: 12),
                _F(ctrl: _subjectCtrl, label: 'Subject',      hint: 'e.g. Mathematics'),
                const SizedBox(height: 12),
                _F(ctrl: _teacherCtrl, label: 'Teacher Name', hint: 'e.g. Mr. Sharma'),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colors[_idx],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Create Class',
                        style: TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _F extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool req;
  const _F({required this.ctrl, required this.label,
    required this.hint, this.req = false});
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    validator: req
        ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
        : null,
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
      hintStyle:  TextStyle(color: Colors.white.withOpacity(0.18), fontSize: 13),
      filled: true, fillColor: const Color(0xFF1E1E32),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}