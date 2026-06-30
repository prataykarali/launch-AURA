import 'package:flutter/material.dart';
import '../../class_data.dart';

class AddTopicSheet extends StatefulWidget {
  final ClassData data;
  final double bottomInset;
  final ValueSetter<String> onAdd;

  const AddTopicSheet({
    super.key,
    required this.data,
    required this.bottomInset,
    required this.onAdd,
  });

  @override
  State<AddTopicSheet> createState() => _AddTopicSheetState();
}

class _AddTopicSheetState extends State<AddTopicSheet> {
  final _controller = TextEditingController();

  void _submit() {
    final val = _controller.text.trim();
    if (val.isNotEmpty) widget.onAdd(val);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 28 + widget.bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF12121F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Add Syllabus Topic',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                widget.onAdd(val.trim());
              }
              Navigator.pop(context);
            },
            decoration: InputDecoration(
              hintText: 'e.g. Quadratic Equations',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(0xFF1E1E32),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.data.accent,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.data.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Add Topic',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
