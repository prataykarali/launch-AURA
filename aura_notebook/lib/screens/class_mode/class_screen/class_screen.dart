import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/services/database_service.dart';
import 'package:aura_notebook/src/rust/api.dart';
import 'package:aura_notebook/utils/responsive.dart';
import '../../home_mode/chat/chat_widget.dart';
import '../class_main_widgets/add_class_sheet.dart';
import '../class_main_widgets/class_card.dart';
import '../class_pages/class_data.dart';
import '../class_pages/class_detail_page.dart';

part 'backdrop.dart';
part 'banner_bar.dart';
part 'stats_row.dart';
part 'menu_sheet.dart';
part 'class_list.dart';
part 'class_body.dart';
part 'ai_overlay.dart';
part 'floating_buttons.dart';
part 'colors.dart';

class ClassScreen extends StatefulWidget {
  const ClassScreen({super.key});
  @override
  State<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<ClassScreen>
    with SingleTickerProviderStateMixin {
  List<ClassData> _classes = [];
  bool _loading = true;

  bool _overlayOpen = false;
  bool _searchActive = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  List<ClassData> get _filtered {
    if (_searchQuery.isEmpty) return _classes;
    final q = _searchQuery.toLowerCase();
    return _classes
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.subject.toLowerCase().contains(q) ||
              c.teacher.toLowerCase().contains(q) ||
              c.section.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  Future<void> _loadClasses() async {
    final classes = await DatabaseService.instance.readAllClasses();
    if (mounted) {
      setState(() {
        _classes = classes;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    auraResetState();
    Navigator.of(context).pop();
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchQuery = '';
        _searchCtrl.clear();
      }
    });
  }

  void _share() {
    final summary = _classes
        .map((c) => '${c.name} (${c.subject}) — ${c.teacher}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: 'My ClassSync Classes:\n\n$summary'));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(_snack('Class list copied to clipboard!'));
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MenuSheet(
        onSort: () {
          Navigator.pop(context);
          _sortClasses();
        },
        onFilter: () {
          Navigator.pop(context);
          _showSnackMsg('Filter coming soon');
        },
        onExport: () {
          Navigator.pop(context);
          _share();
        },
        onAbout: () {
          Navigator.pop(context);
          _showSnackMsg('AURA ClassSync v1.0');
        },
      ),
    );
  }

  void _sortClasses() {
    setState(() => _classes.sort((a, b) => a.name.compareTo(b.name)));
    ScaffoldMessenger.of(context).showSnackBar(_snack('Sorted A → Z'));
  }

  void _showSnackMsg(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(_snack(msg));

  SnackBar _snack(String msg) => SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white)),
    backgroundColor: const Color(0xFF1A1A2E),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  );

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddClassSheet(
        onSubmit: (data) async {
          await DatabaseService.instance.createClass(data);
          _loadClasses();
          Navigator.pop(context);
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  void _confirmDelete(ClassData c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Class',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Delete "${c.name}"?\nThis cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (c.id != null) {
                await DatabaseService.instance.deleteClass(c.id!);
                _loadClasses();
              }
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(_snack('${c.name} deleted'));
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: _ClassScreenBody(
        classes: _classes,
        filtered: _filtered,
        loading: _loading,
        searchActive: _searchActive,
        searchQuery: _searchQuery,
        searchCtrl: _searchCtrl,
        overlayOpen: _overlayOpen,
        onBack: _goBack,
        onSearch: _toggleSearch,
        onShare: _share,
        onMenu: _showMenu,
        onSearchChanged: (v) => setState(() => _searchQuery = v),
        onCloseOverlay: () => setState(() => _overlayOpen = false),
        onClassTap: (data) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClassDetailPage(data: data),
          ),
        ),
        onClassDelete: _confirmDelete,
      ),
      floatingActionButton: _overlayOpen
          ? null
          : _ClassFloatingButtons(
              onAiTap: () {
                HapticFeedback.mediumImpact();
                setState(() => _overlayOpen = true);
              },
              onAddTap: _openAddSheet,
              pulseAnim: _pulseAnim,
            ),
    );
  }
}
