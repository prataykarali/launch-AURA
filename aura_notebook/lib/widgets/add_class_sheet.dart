import 'package:flutter/material.dart';
import '../screens/class_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AddClassSheet — bottom sheet for creating a new class
// Uses kSubjectThemes for the subject picker with icons + colours
// ─────────────────────────────────────────────────────────────────────────────
class AddClassSheet extends StatefulWidget {
  final void Function(ClassData) onSubmit;
  const AddClassSheet({super.key, required this.onSubmit});
  @override
  State<AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<AddClassSheet> {
  final _nameCtrl    = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  int _idx = 0; // selected subject index

  @override
  void dispose() {
    _nameCtrl.dispose(); _sectionCtrl.dispose(); _teacherCtrl.dispose();
    super.dispose();
  }

  SubjectTheme get _selected => kSubjectThemes[_idx];

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final t = _selected;
    widget.onSubmit(ClassData(
      name:     _nameCtrl.text.trim(),
      section:  _sectionCtrl.text.trim(),
      subject:  t.name,
      teacher:  _teacherCtrl.text.trim(),
      students: 0,
      color:    t.color,
      accent:   t.accent,
      icon:     t.icon,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF12121F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                // Handle
                Center(child: Container(
                  width: 38, height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2)),
                )),

                // Title
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _selected.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_selected.icon, color: _selected.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text('Create a Class',
                      style: TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 22),

                // Subject picker
                _Label('SUBJECT'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kSubjectThemes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final t = kSubjectThemes[i];
                      final sel = i == _idx;
                      return GestureDetector(
                        onTap: () => setState(() => _idx = i),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width:  sel ? 50 : 42,
                              height: sel ? 50 : 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [t.color, Color.lerp(t.color, t.accent, 0.5)!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: sel
                                    ? Border.all(color: Colors.white, width: 2.5)
                                    : Border.all(color: Colors.white12),
                                boxShadow: sel ? [BoxShadow(
                                    color: t.color.withOpacity(0.5), blurRadius: 10)] : null,
                              ),
                              child: Icon(t.icon,
                                  color: Colors.white,
                                  size: sel ? 22 : 18),
                            ),
                            const SizedBox(height: 4),
                            Text(t.name,
                              style: TextStyle(
                                color: sel ? t.accent : Colors.white.withOpacity(0.3),
                                fontSize: 9, fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Preview strip
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_selected.color, _selected.accent],
                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _nameCtrl.text.isEmpty ? _selected.name : _nameCtrl.text,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _F(ctrl: _nameCtrl,    label: 'Class Name *',  hint: 'e.g. Advanced Mathematics', req: true),
                const SizedBox(height: 12),
                _F(ctrl: _sectionCtrl, label: 'Section',       hint: 'e.g. Grade 10 · Section A'),
                const SizedBox(height: 12),
                _F(ctrl: _teacherCtrl, label: 'Teacher Name',  hint: 'e.g. Mr. Sharma'),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selected.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Create Class',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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

class _Label extends StatelessWidget {
  final String text; const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
          color: Colors.white.withOpacity(0.3), letterSpacing: 1.6));
}

class _F extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool req;
  const _F({required this.ctrl, required this.label, required this.hint,
    this.req = false});
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    validator: req ? (v) => (v == null || v.trim().isEmpty)
        ? '$label is required' : null : null,
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
      hintStyle:  TextStyle(color: Colors.white.withOpacity(0.18), fontSize: 13),
      filled: true, fillColor: const Color(0xFF1E1E32),
      border:       OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}