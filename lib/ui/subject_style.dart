import 'package:flutter/material.dart';

import '../data/models.dart';

IconData subjectIcon(Subject subject) => switch (subject) {
  Subject.chinese => Icons.menu_book_rounded,
  Subject.math => Icons.functions_rounded,
  Subject.english => Icons.translate_rounded,
  Subject.physics => Icons.bolt_rounded,
  Subject.chemistry => Icons.science_rounded,
  Subject.biology => Icons.eco_rounded,
};

Color subjectColor(Subject subject, Brightness brightness) {
  final base = switch (subject) {
    Subject.chinese => const Color(0xFFB0644E),
    Subject.math => const Color(0xFF3F7D5C),
    Subject.english => const Color(0xFF4F74A8),
    Subject.physics => const Color(0xFF7563A8),
    Subject.chemistry => const Color(0xFFB2824C),
    Subject.biology => const Color(0xFF4C8C7A),
  };
  return brightness == Brightness.dark
      ? Color.lerp(base, Colors.white, 0.32)!
      : base;
}
