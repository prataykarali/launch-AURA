import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Future<String> generateTrayIcon() async {
  // Draw a small purple circle with a star — no image needed
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = 32.0;

  // Background: transparent
  final bgPaint = Paint()..color = Colors.transparent;
  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), bgPaint);

  // Outer glow circle
  final glowPaint = Paint()
    ..color = const Color(0xFFD5A3FF).withOpacity(0.4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  canvas.drawCircle(const Offset(16, 16), 13, glowPaint);

  // Solid circle
  final circlePaint = Paint()
    ..shader = const RadialGradient(
      colors: [Color(0xFFFF9CEE), Color(0xFF7C3AED)],
    ).createShader(const Rect.fromLTWH(0, 0, size, size));
  canvas.drawCircle(const Offset(16, 16), 11, circlePaint);

  // Star dot in center
  final dotPaint = Paint()..color = Colors.white.withOpacity(0.9);
  canvas.drawCircle(const Offset(16, 16), 3, dotPaint);

  final picture = recorder.endRecording();
  final img = await picture.toImage(32, 32);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

  // Save to temp file
  final tmp = await getTemporaryDirectory();
  final file = File('${tmp.path}/aura_tray.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file.path;
}