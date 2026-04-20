import 'package:flutter/material.dart';
import '../class_data.dart';
import '../detail_widgets/dark_card.dart';
import '../detail_widgets/section_label.dart';
import '../detail_widgets/empty_state.dart';
import '../detail_widgets/ai_lesson_summariser.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// LessonsTab — lesson planner with empty state, progress ring, add sheet.
///
/// IMAGE PLACEHOLDER:
///   • Assets/images/empty_lessons.png  → empty state illustration (300×250)
///     Suggest: a cartoon open book with sparkles, or a blank chalkboard
// ─────────────────────────────────────────────────────────────────────────────
class LessonsTab extends StatefulWidget {
  final ClassData data;
  const LessonsTab({super.key, required this.data});
  @override
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab> {
  final List<_Lesson> _lessons = [];   // ← starts empty

  int get _done => _lessons.where((l) => l.done).length;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        // ── Top bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            Expanded(
              child: _lessons.isEmpty
                  ? Text('No lessons yet',
                  style: TextStyle(color: Colors.white.withOpacity(0.3),
                      fontSize: 12))
                  : Text('$_done / ${_lessons.length} completed',
                  style: TextStyle(color: d.accent, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            _AddButton(
              label: 'Add Lesson', accent: d.accent, color: d.color,
              onTap: () => _showSheet(context, d),
            ),
          ]),
        ),

        // ── Empty or list ───────────────────────────────────────────────
        Expanded(
          child: _lessons.isEmpty
              ? EmptyState(
            // IMAGE PLACEHOLDER: Assets/images/empty_lessons.png
            imagePath: 'Assets/images/empty_lessons.png',
            title: 'No Lessons Yet',
            subtitle: 'Tap "Add Lesson" to plan your first topic.',
            accent: d.accent,
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: _lessons.length,
            itemBuilder: (_, i) => _LessonTile(
              lesson: _lessons[i],
              accent: d.accent,
              index: i + 1,
              onToggle: () => setState(() =>
              _lessons[i] = _lessons[i].toggle()),
              onDelete: () => setState(() => _lessons.removeAt(i)),
            ),
          ),
        ),
      ],
    );
  }

  void _showSheet(BuildContext ctx, ClassData d) {
    final titleCtrl   = TextEditingController();
    final objCtrl     = TextEditingController();
    final taskCtrl    = TextEditingController();
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final b = MediaQuery.of(ctx).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 28 + b),
          decoration: const BoxDecoration(
            color: Color(0xFF12121F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: Color(0x335C6BC0))),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)))),
              const Text('New Lesson',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _SF(ctrl: titleCtrl, label: 'Topic Title *', hint: 'e.g. Quadratic Equations'),
              const SizedBox(height: 10),
              _SF(ctrl: objCtrl,   label: 'Learning Objectives', hint: 'What students should learn…', lines: 3),
              const SizedBox(height: 10),
              _SF(ctrl: taskCtrl,  label: 'Assigned Task', hint: 'Homework / practice problems…'),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isNotEmpty) {
                      setState(() => _lessons.add(_Lesson(
                        title: titleCtrl.text.trim(),
                        objectives: objCtrl.text.trim(),
                        task: taskCtrl.text.trim(),
                        week: 'Week ${_lessons.length + 1}',
                      )));
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: d.color,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: const Text('Add Lesson',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Lesson {
  final String title, objectives, task, week;
  final bool done;
  const _Lesson({required this.title, this.objectives = '',
    this.task = '', required this.week, this.done = false});
  _Lesson toggle() => _Lesson(title: title, objectives: objectives,
      task: task, week: week, done: !done);
}

class _LessonTile extends StatelessWidget {
  final _Lesson lesson; final Color accent;
  final int index;
  final VoidCallback onToggle, onDelete;
  const _LessonTile({required this.lesson, required this.accent,
    required this.index, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF161625),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: lesson.done
          ? accent.withOpacity(0.25) : Colors.white.withOpacity(0.06)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        leading: GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lesson.done ? accent : Colors.transparent,
              border: Border.all(
                  color: lesson.done ? accent : Colors.white30, width: 2),
            ),
            child: lesson.done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Center(child: Text('$index',
                style: TextStyle(color: Colors.white38, fontSize: 10,
                    fontWeight: FontWeight.w700))),
          ),
        ),
        title: Text(lesson.title,
            style: TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600,
              decoration: lesson.done ? TextDecoration.lineThrough : null,
              decorationColor: Colors.white30,
            )),
        subtitle: lesson.objectives.isNotEmpty
            ? Text(lesson.objectives, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.33), fontSize: 11))
            : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(lesson.week,
              style: TextStyle(color: accent.withOpacity(0.65), fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded,
                size: 16, color: Colors.white.withOpacity(0.2)),
          ),
        ]),
      ),
      AiLessonSummariser(
        lessonTitle: lesson.title,
        objectives:  lesson.objectives,
        accent:      accent,
      ),
      if (lesson.task.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            Icon(Icons.assignment_outlined, size: 12,
                color: accent.withOpacity(0.5)),
            const SizedBox(width: 6),
            Expanded(child: Text(lesson.task,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.38),
                    fontSize: 11))),
          ]),
        ),
    ]),
  );
}

// ── Sheet helpers ─────────────────────────────────────────────────────────────
class _SF extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final int lines;
  const _SF({required this.ctrl, required this.label,
    required this.hint, this.lines = 1});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, maxLines: lines, minLines: 1,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 12),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.18), fontSize: 13),
      filled: true, fillColor: const Color(0xFF1E1E32),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
  );
}

class _AddButton extends StatelessWidget {
  final String label; final Color accent, color; final VoidCallback onTap;
  const _AddButton({required this.label, required this.accent,
    required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.38)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_rounded, size: 14, color: accent),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: accent, fontSize: 12,
            fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}