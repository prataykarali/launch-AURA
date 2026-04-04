import 'package:flutter/material.dart';
import '../class_data.dart';
import '../detail_widgets/empty_state.dart';

class StreamTab extends StatefulWidget {
  final ClassData data;
  const StreamTab({super.key, required this.data});
  @override
  State<StreamTab> createState() => _StreamTabState();
}

class _StreamTabState extends State<StreamTab> {
  final List<_Post> _posts = [];
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final h = _ctrl.text.isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  void _post() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() => _posts.insert(0,
        _Post(author: 'You', text: t, time: 'Just now',
            icon: Icons.person_rounded, isMe: true)));
    _ctrl.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        Expanded(
          child: _posts.isEmpty
              ? EmptyState(
            // No image placeholder needed here — icon is fine
            title: 'No Posts Yet',
            subtitle: 'Be the first to post to the class stream!',
            accent: d.accent,
            icon: Icons.campaign_outlined,
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            itemCount: _posts.length,
            itemBuilder: (_, i) => _PostCard(
              post: _posts[i], accent: d.accent,
              onDelete: _posts[i].isMe
                  ? () => setState(() => _posts.removeAt(i))
                  : null,
            ),
          ),
        ),

        // ── Input bar ────────────────────────────────────────────────
        Container(
          color: const Color(0xFF0D0D18),
          padding: EdgeInsets.only(
            left: 16, right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            top: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E32),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _hasText
                          ? d.accent.withOpacity(0.4)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: TextField(
                    controller: _ctrl, focusNode: _focus,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onSubmitted: (_) => _post(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'Post to stream…',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.22), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _post,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _hasText
                        ? LinearGradient(colors: [d.color, d.accent],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                        : null,
                    color: !_hasText ? Colors.white.withOpacity(0.08) : null,
                  ),
                  child: Icon(Icons.send_rounded,
                      color: _hasText ? Colors.white : Colors.white.withOpacity(0.22),
                      size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Post {
  final String author, text, time; final IconData icon; final bool isMe;
  const _Post({required this.author, required this.text, required this.time,
    required this.icon, this.isMe = false});
}

class _PostCard extends StatelessWidget {
  final _Post post; final Color accent; final VoidCallback? onDelete;
  const _PostCard({required this.post, required this.accent, this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: post.isMe
          ? accent.withOpacity(0.07)
          : const Color(0xFF161625),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: post.isMe
          ? accent.withOpacity(0.2) : Colors.white.withOpacity(0.06)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(radius: 14,
            backgroundColor: accent.withOpacity(0.15),
            child: Text(post.author[0],
                style: TextStyle(color: accent, fontSize: 11,
                    fontWeight: FontWeight.w800))),
        const SizedBox(width: 8),
        Expanded(child: Text(post.author,
            style: const TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w600))),
        Text(post.time,
            style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 11)),
        if (onDelete != null) ...[
          const SizedBox(width: 8),
          GestureDetector(onTap: onDelete,
              child: Icon(Icons.close_rounded,
                  size: 15, color: Colors.white.withOpacity(0.2))),
        ],
      ]),
      const SizedBox(height: 8),
      Text(post.text,
          style: TextStyle(color: Colors.white.withOpacity(0.65),
              fontSize: 13, height: 1.5)),
    ]),
  );
}