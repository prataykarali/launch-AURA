import 'package:flutter/material.dart';
import '../class_data.dart';
import '../detail_widgets/empty_state.dart';

// IMAGE PLACEHOLDER:
//   • Assets/images/empty_resources.png → empty state (300×250)
//     Suggest: folder with documents floating out

class ResourcesTab extends StatefulWidget {
  final ClassData data;
  const ResourcesTab({super.key, required this.data});
  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {

  final List<_Resource> _items = [];  // ← starts empty

  // Filter state
  String _filter = 'All';
  static const _filters = ['All', 'PDF', 'PPT', 'Link', 'Note'];

  List<_Resource> get _filtered =>
      _filter == 'All' ? _items : _items.where((r) => r.type == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        // ── Upload strip ────────────────────────────────────────────────
        _UploadStrip(data: d, onAdd: () => _showAddSheet(context, d)),

        // ── Filter chips ────────────────────────────────────────────────
        if (_items.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _filter = _filters[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: _filter == _filters[i]
                        ? d.color : const Color(0xFF1E1E32),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filter == _filters[i]
                          ? d.accent.withOpacity(0.4)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Text(_filters[i],
                      style: TextStyle(
                        color: _filter == _filters[i] ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        fontSize: 11, fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            ),
          ),

        // ── List or empty ───────────────────────────────────────────────
        Expanded(
          child: _items.isEmpty
              ? EmptyState(
            imagePath: 'Assets/images/empty_resources.png',
            title: 'No Resources Yet',
            subtitle: 'Upload PDFs, slides, or add links for your class.',
            accent: d.accent,
          )
              : _filtered.isEmpty
              ? Center(child: Text('No $_filter files',
              style: TextStyle(color: Colors.white.withOpacity(0.3))))
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _filtered.length,
            itemBuilder: (_, i) => _ResourceTile(
              item: _filtered[i], accent: d.accent,
              onDelete: () => setState(() => _items.remove(_filtered[i])),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext ctx, ClassData d) {
    final nameCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    String selectedType = 'PDF';

    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final b = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (_, setSt) => Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 28 + b),
            decoration: const BoxDecoration(
              color: Color(0xFF12121F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: Color(0x335C6BC0))),
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)))),
                const Text('Add Resource',
                    style: TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                // Type selector
                Wrap(spacing: 8, children: ['PDF', 'PPT', 'Link', 'Note'].map((t) =>
                    GestureDetector(
                      onTap: () => setSt(() => selectedType = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selectedType == t ? d.color : const Color(0xFF1E1E32),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selectedType == t
                              ? d.accent.withOpacity(0.4)
                              : Colors.white.withOpacity(0.1)),
                        ),
                        child: Text(t, style: TextStyle(
                          color: selectedType == t
                              ? Colors.white : Colors.white.withOpacity(0.4),
                          fontSize: 12, fontWeight: FontWeight.w600,
                        )),
                      ),
                    )).toList(),
                ),
                const SizedBox(height: 14),
                _SF(ctrl: nameCtrl, label: 'Resource Name *',
                    hint: 'e.g. Chapter 3 Notes'),
                const SizedBox(height: 10),
                if (selectedType == 'Link')
                  _SF(ctrl: linkCtrl, label: 'URL', hint: 'https://…'),
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isNotEmpty) {
                        setState(() => _items.insert(0, _Resource(
                          name: nameCtrl.text.trim(),
                          type: selectedType,
                          size: selectedType == 'Link' ? '' : '—',
                          url: linkCtrl.text.trim(),
                        )));
                      }
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: d.color,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: const Text('Add Resource',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Resource {
  final String name, type, size, url;
  const _Resource({required this.name, required this.type,
    this.size = '', this.url = ''});
}

class _UploadStrip extends StatelessWidget {
  final ClassData data; final VoidCallback onAdd;
  const _UploadStrip({required this.data, required this.onAdd});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: data.accent.withOpacity(0.22), width: 1.5),
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: data.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.cloud_upload_outlined, color: data.accent, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Upload Resource',
                style: TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w700)),
            Text('PDF, PPT, Link, Note  ·  Max 50 MB',
                style: TextStyle(color: Colors.white.withOpacity(0.33), fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: data.color,
                borderRadius: BorderRadius.circular(20)),
            child: const Text('+ Add',
                style: TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    ),
  );
}

class _ResourceTile extends StatelessWidget {
  final _Resource item; final Color accent; final VoidCallback onDelete;
  const _ResourceTile({required this.item, required this.accent,
    required this.onDelete});

  IconData get _icon => switch (item.type) {
    'PDF'  => Icons.picture_as_pdf_rounded,
    'PPT'  => Icons.slideshow_rounded,
    'Link' => Icons.link_rounded,
    _      => Icons.note_outlined,
  };
  Color get _color => switch (item.type) {
    'PDF'  => const Color(0xFFEF5350),
    'PPT'  => const Color(0xFFFF7043),
    'Link' => const Color(0xFF42A5F5),
    _      => const Color(0xFFAB47BC),
  };

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF161625),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(_icon, color: _color, size: 20)),
      title: Text(item.name,
          style: const TextStyle(color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w600)),
      subtitle: Text(item.type + (item.size.isNotEmpty ? '  ·  ${item.size}' : ''),
          style: TextStyle(color: Colors.white.withOpacity(0.33), fontSize: 11)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.download_outlined,
            size: 18, color: Colors.white.withOpacity(0.22)),
        const SizedBox(width: 8),
        GestureDetector(onTap: onDelete,
            child: Icon(Icons.close_rounded,
                size: 16, color: Colors.white.withOpacity(0.18))),
      ]),
    ),
  );
}

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
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.18), fontSize: 13),
      filled: true, fillColor: const Color(0xFF1E1E32),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
  );
}