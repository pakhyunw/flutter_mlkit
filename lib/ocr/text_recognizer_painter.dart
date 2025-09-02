import 'dart:ui';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../vision_detector_views/painters/coordinates_translator.dart';

class TextRecognizerPainter extends CustomPainter {
  TextRecognizerPainter(
      this.recognizedText,
      this.absoluteImageSize,
      this.rotation,
      this.renderBox,
      this.getScannedText,
      this.cameraLensDirection,
      {this.roiBoxSize = const Size(800, 400),
      this.getRawData,
      this.paintboxCustom,
      required this.isLiveFeed});

  /// ML kit recognizer
  final RecognizedText recognizedText;

  /// Image scanned size
  final Size absoluteImageSize;

  /// Image scanned rotation
  final InputImageRotation rotation;

  /// Render box for narrow camera
  final RenderBox renderBox;

  /// Function to get scanned text as a string
  final Function getScannedText;

  /// Scanned text string
  String scannedText = "";

  /// box Size
  final Size? roiBoxSize;

  /// Get raw data from scanned image
  final Function? getRawData;

  /// Narower box paint
  final Paint? paintboxCustom;

  final bool isLiveFeed;

  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    scannedText = "";

    final Paint background = Paint()..color = Colors.amberAccent;

    // ROI 박스 크기 계산
    final double roiBoxWidth = roiBoxSize!.width / 2;
    final double roiBoxHeight = roiBoxSize!.height / 2;

    final double boxLeft = (size.width - roiBoxWidth) / 2;
    final double boxTop = (size.height - roiBoxHeight) / 2;
    final double boxRight = boxLeft + roiBoxWidth;
    final double boxBottom = boxTop + roiBoxHeight;

    final Paint paintbox = paintboxCustom ??
        (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.amberAccent);

    final rect = RRect.fromLTRBR(
        boxLeft, boxTop, boxRight, boxBottom, const Radius.circular(15));

    // ROI 박스 그리기
    canvas.drawRRect(rect, paintbox);

    List textBlocks = [];

    for (final textBunk in recognizedText.blocks) {
      for (final line in textBunk.lines) {
        for (final element in line.elements) {
          final left = translateX(element.boundingBox.left, size,
              absoluteImageSize, rotation, cameraLensDirection);
          final top = translateY(element.boundingBox.top, size,
              absoluteImageSize, rotation, cameraLensDirection);
          final right = translateX(element.boundingBox.right, size,
              absoluteImageSize, rotation, cameraLensDirection);
          final bottom = translateY(element.boundingBox.bottom, size,
              absoluteImageSize, rotation, cameraLensDirection);

          final bool isInsideRoi = left >= boxLeft && right <= boxRight && top >= boxTop && bottom <= boxBottom;

          // === ROI 안에 "완전히" 포함될 때만 허용 ===
          if (isInsideRoi) {
            textBlocks.add(element);
            scannedText += " ${element.text}";

            final ParagraphBuilder builder = ParagraphBuilder(
              ParagraphStyle(
                textAlign: TextAlign.left,
                fontSize: 28,
                textDirection: TextDirection.ltr,
              ),
            );
            builder.pushStyle(
                ui.TextStyle(color: Colors.white, background: background));

            if (isLiveFeed) builder.addText(element.text);
            builder.pop();

            canvas.drawParagraph(
              builder.build()
                ..layout(ParagraphConstraints(width: right - left)),
              Offset(left, top),
            );
          }
        }
      }
    }

    if (getRawData != null) {
      getRawData!(textBlocks);
    }
    getScannedText(scannedText);
  }

  @override
  bool shouldRepaint(TextRecognizerPainter oldDelegate) {
    return oldDelegate.recognizedText != recognizedText;
  }
}
