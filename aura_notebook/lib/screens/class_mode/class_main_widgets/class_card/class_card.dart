import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../class_pages/class_data.dart';

part 'class_card_colors.dart';
part 'class_card_header.dart';
part 'class_card_body.dart';
part 'class_card_options_sheet.dart';

class ClassCard extends StatefulWidget {
  final ClassData data;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const ClassCard({super.key, required this.data, this.onTap, this.onDelete});
  @override
  State<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<ClassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  // Generate a deterministic 6-char class code from the class name
  String get _classCode {
    final seed = widget.data.name.codeUnits.fold(0, (a, b) => a + b);
    final rng = Random(seed);
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.975,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _showOptions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardOptionsSheet(
        data: widget.data,
        classCode: _classCode,
        onOpen: () {
          Navigator.pop(context);
          widget.onTap?.call();
        },
        onShare: () {
          Navigator.pop(context);
          _shareCode();
        },
        onDelete: widget.onDelete == null
            ? null
            : () {
                Navigator.pop(context);
                widget.onDelete?.call();
              },
      ),
    );
  }

  void _shareCode() {
    // In a real app: Share.share('Join ${widget.data.name} with code: $_classCode');
    Clipboard.setData(ClipboardData(text: _classCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Class code "$_classCode" copied to clipboard!'),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _press.reverse(),
        onLongPress: _showOptions,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: d.accent.withOpacity(0.14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(d: d, classCode: _classCode, onOptions: _showOptions),
                _Body(d: d),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
