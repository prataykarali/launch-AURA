import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClassData — shared model across all screens
// ─────────────────────────────────────────────────────────────────────────────
class ClassData {
  final String   name, section, subject, teacher;
  final int      students;
  final Color    color, accent;
  final IconData icon;

  const ClassData({
    required this.name,
    required this.section,
    required this.subject,
    required this.teacher,
    required this.students,
    required this.color,
    required this.accent,
    required this.icon,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SubjectTheme — maps subject names to colors, icons, asset paths
// Used by AddClassSheet and ClassDetailPage header
// ─────────────────────────────────────────────────────────────────────────────
class SubjectTheme {
  final String   name;
  final Color    color, accent;
  final IconData icon;
  // IMAGE PLACEHOLDER: add Assets/images/banner_<key>.png for each
  // e.g. banner_maths.png, banner_science.png … (800×400 px, wide illustration)
  final String   bannerAsset;
  // Predefined syllabus topics for this subject
  final List<String> defaultTopics;

  const SubjectTheme({
    required this.name,
    required this.color,
    required this.accent,
    required this.icon,
    required this.bannerAsset,
    required this.defaultTopics,
  });
}

const List<SubjectTheme> kSubjectThemes = [
  SubjectTheme(
    name: 'Maths',
    color:  Color(0xFF1565C0), accent: Color(0xFF64B5F6),
    icon: Icons.calculate_rounded,
    bannerAsset: 'Assets/images/banner_maths.png',
    defaultTopics: [
      'Number Systems', 'Algebra Basics', 'Linear Equations',
      'Quadratic Equations', 'Geometry', 'Trigonometry',
      'Statistics', 'Probability', 'Calculus Intro',
    ],
  ),
  SubjectTheme(
    name: 'Science',
    color:  Color(0xFF00695C), accent: Color(0xFF4DD0C4),
    icon: Icons.science_rounded,
    bannerAsset: 'Assets/images/banner_science.png',
    defaultTopics: [
      'Matter & States', 'Motion & Forces', 'Energy Forms',
      'Light & Sound', 'Electricity', 'Chemical Reactions',
      'Cell Biology', 'Ecosystems', 'The Universe',
    ],
  ),
  SubjectTheme(
    name: 'English',
    color:  Color(0xFF4527A0), accent: Color(0xFF9575CD),
    icon: Icons.menu_book_rounded,
    bannerAsset: 'Assets/images/banner_english.png',
    defaultTopics: [
      'Grammar Foundations', 'Reading Comprehension', 'Essay Writing',
      'Poetry Analysis', 'Spoken English', 'Creative Writing',
      'Literature Study', 'Debate & Discussion',
    ],
  ),
  SubjectTheme(
    name: 'Arts',
    color:  Color(0xFF6A1B9A), accent: Color(0xFFCE93D8),
    icon: Icons.brush_rounded,
    bannerAsset: 'Assets/images/banner_arts.png',
    defaultTopics: [
      'Colour Theory', 'Sketching Basics', 'Watercolour',
      'Digital Art Intro', 'Sculpture', 'Art History',
      'Mixed Media', 'Portfolio Project',
    ],
  ),
  SubjectTheme(
    name: 'Music',
    color:  Color(0xFF880E4F), accent: Color(0xFFF48FB1),
    icon: Icons.music_note_rounded,
    bannerAsset: 'Assets/images/banner_music.png',
    defaultTopics: [
      'Music Theory', 'Rhythm & Beat', 'Scales & Chords',
      'Vocal Training', 'Instrument Basics', 'Notation Reading',
      'Composition', 'Performance Practice',
    ],
  ),
  SubjectTheme(
    name: 'Sports',
    color:  Color(0xFF1B5E20), accent: Color(0xFF69F0AE),
    icon: Icons.sports_soccer_rounded,
    bannerAsset: 'Assets/images/banner_sports.png',
    defaultTopics: [
      'Fitness Basics', 'Athletics', 'Team Sports Rules',
      'Swimming', 'Yoga & Flexibility', 'Sports Psychology',
      'Nutrition for Sports', 'First Aid',
    ],
  ),
  SubjectTheme(
    name: 'Economics',
    color:  Color(0xFFE65100), accent: Color(0xFFFFCC80),
    icon: Icons.trending_up_rounded,
    bannerAsset: 'Assets/images/banner_economics.png',
    defaultTopics: [
      'Demand & Supply', 'Market Structures', 'GDP & Growth',
      'Inflation', 'International Trade', 'Fiscal Policy',
      'Banking System', 'Development Economics',
    ],
  ),
  SubjectTheme(
    name: 'Computer Science',
    color:  Color(0xFF006064), accent: Color(0xFF80DEEA),
    icon: Icons.computer_rounded,
    bannerAsset: 'Assets/images/banner_cs.png',
    defaultTopics: [
      'Intro to Programming', 'Variables & Data Types', 'Control Flow',
      'Functions', 'Arrays & Lists', 'OOP Concepts',
      'Algorithms', 'Databases', 'Networking Basics',
    ],
  ),
  SubjectTheme(
    name: 'Hardware',
    color:  Color(0xFF37474F), accent: Color(0xFFB0BEC5),
    icon: Icons.memory_rounded,
    bannerAsset: 'Assets/images/banner_hardware.png',
    defaultTopics: [
      'CPU Architecture', 'Memory Types', 'Motherboard Components',
      'Storage Devices', 'Input/Output', 'Networking Hardware',
      'Assembly & Disassembly', 'Troubleshooting',
    ],
  ),
  SubjectTheme(
    name: 'Humanities',
    color:  Color(0xFF4E342E), accent: Color(0xFFBCAAA4),
    icon: Icons.public_rounded,
    bannerAsset: 'Assets/images/banner_humanities.png',
    defaultTopics: [
      'Ancient Civilisations', 'World Wars', 'Geography Basics',
      'Political Systems', 'Philosophy Intro', 'Ethics',
      'Cultural Studies', 'Human Rights',
    ],
  ),
  SubjectTheme(
    name: 'Languages',
    color:  Color(0xFF00695C), accent: Color(0xFFA5D6A7),
    icon: Icons.translate_rounded,
    bannerAsset: 'Assets/images/banner_languages.png',
    defaultTopics: [
      'Alphabet & Pronunciation', 'Basic Vocabulary',
      'Sentence Structure', 'Greetings & Phrases',
      'Reading Passages', 'Listening Practice',
      'Writing Skills', 'Conversation',
    ],
  ),
  SubjectTheme(
    name: 'Physics',
    color:  Color(0xFF1A237E), accent: Color(0xFF90CAF9),
    icon: Icons.bolt_rounded,
    bannerAsset: 'Assets/images/banner_physics.png',
    defaultTopics: [
      'Kinematics', 'Newton\'s Laws', 'Work & Energy',
      'Waves', 'Optics', 'Electrostatics',
      'Current Electricity', 'Modern Physics',
    ],
  ),
];

// Helper — find theme by name (case-insensitive), fallback to first
SubjectTheme themeFor(String subject) {
  final key = subject.toLowerCase().trim();
  return kSubjectThemes.firstWhere(
        (t) => t.name.toLowerCase() == key,
    orElse: () => kSubjectThemes.first,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// XP / Level helpers
// ─────────────────────────────────────────────────────────────────────────────
class XpSystem {
  static int xpForLevel(int level) => 200 + (level - 1) * 150;

  static int levelFromXp(int xp) {
    int level = 1;
    int cumulative = 0;
    while (true) {
      final needed = xpForLevel(level);
      if (cumulative + needed > xp) return level;
      cumulative += needed;
      level++;
    }
  }

  static int xpInCurrentLevel(int xp) {
    int level = 1;
    int cumulative = 0;
    while (true) {
      final needed = xpForLevel(level);
      if (cumulative + needed > xp) return xp - cumulative;
      cumulative += needed;
      level++;
    }
  }

  static int xpNeededForCurrentLevel(int xp) {
    final level = levelFromXp(xp);
    return xpForLevel(level);
  }

  static String levelTitle(int level) => switch (level) {
    1 => 'Beginner',
    2 => 'Learner',
    3 => 'Rising',
    4 => 'Skilled',
    5 => 'Advanced',
    6 => 'Expert',
    7 => 'Master',
    _ => 'Legend',
  };
}