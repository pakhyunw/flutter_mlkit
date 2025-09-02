import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'coordinates_translator.dart';

class TextRecognizerPainter extends CustomPainter {
  TextRecognizerPainter(this.recognizedText, this.absoluteImageSize,
      this.rotation, this.renderBox, this.getScannedText,
      {this.roiBoxSize = const Size(400, 200),
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

  @override
  void paint(Canvas canvas, Size size) {
    scannedText = "";

    final Paint background = Paint()..color = Colors.amberAccent;

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

    canvas.drawRRect(rect, paintbox,);
    List textBlocks = [];
    for (final textBunk in recognizedText.blocks) {
      for (final element in textBunk.lines) {
        for (final textBlock in element.elements) {
          final left = translateX(
              (textBlock.boundingBox.left), rotation, size, absoluteImageSize);
          final top = translateY(
              (textBlock.boundingBox.top), rotation, size, absoluteImageSize);
          final right = translateX(
              (textBlock.boundingBox.right), rotation, size, absoluteImageSize);

          if (left >= boxLeft &&
              right <= boxRight &&
              (top >= (boxTop + 15) && top <= (boxBottom - 20))) {
            textBlocks.add(textBlock);

            var parsedText = textBlock.text;
            scannedText += " ${textBlock.text}";

            final ParagraphBuilder builder = ParagraphBuilder(
              ParagraphStyle(
                  textAlign: TextAlign.left,
                  fontSize: 14,
                  textDirection: TextDirection.ltr),
            );
            builder.pushStyle(
                ui.TextStyle(color: Colors.white, background: background));
            if (isLiveFeed) builder.addText(parsedText);
            builder.pop();

            canvas.drawParagraph(
              builder.build()
                ..layout(ParagraphConstraints(
                  width: right - left,
                )),
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
