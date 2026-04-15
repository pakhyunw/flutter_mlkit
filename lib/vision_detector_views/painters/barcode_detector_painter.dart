import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../barcode_scanner_view.dart';
import 'coordinates_translator.dart';

class BarcodeDetectorPainter extends CustomPainter {
  BarcodeDetectorPainter(
    this.barcodes,
    this.imageSize,
    this.rotation,
    this.cameraLensDirection,
    this.mode,
  );

  final List<Barcode> barcodes;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final ScanMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final bool isLandscape = size.width > size.height;
    final double roiBoxSize = (isLandscape ? size.height : size.width) * 0.5;
    final double roiLeft = (size.width - roiBoxSize) / 2;
    final double roiTop = (size.height - roiBoxSize) / 2;
    final double roiRight = roiLeft + roiBoxSize;
    final double roiBottom = roiTop + roiBoxSize;

    final bool showRoi = mode == ScanMode.single || mode == ScanMode.continuous;

    if (showRoi) {
      final Paint roiPaint = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      const double cornerRadius = 15.0;
      final rrect = RRect.fromLTRBR(
          roiLeft, roiTop, roiRight, roiBottom, const Radius.circular(cornerRadius));

      // Draw ROI Box
      canvas.drawRRect(rrect, roiPaint);
    }

    for (final Barcode barcode in barcodes) {
      final double barcodeLeft = translateX(
        barcode.boundingBox.left,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final double barcodeRight = translateX(
        barcode.boundingBox.right,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final double barcodeTop = translateY(
        barcode.boundingBox.top,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final double barcodeBottom = translateY(
        barcode.boundingBox.bottom,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );

      // Check if barcode is inside ROI
      final bool isInside = barcodeLeft >= roiLeft &&
          barcodeRight <= roiRight &&
          barcodeTop >= roiTop &&
          barcodeBottom <= roiBottom;

      // For single/continuous, only highlight if inside ROI
      // For find/multi, highlight everything
      final bool shouldHighlight = !showRoi || isInside;

      if (shouldHighlight) {
        // Draw barcode corners (Highlight)
        final List<Offset> cornerOffsets = barcode.cornerPoints.map((point) {
          return Offset(
            translateX(point.x.toDouble(), size, imageSize, rotation,
                cameraLensDirection),
            translateY(point.y.toDouble(), size, imageSize, rotation,
                cameraLensDirection),
          );
        }).toList();

        if (cornerOffsets.isNotEmpty) {
          cornerOffsets.add(cornerOffsets.first);
          canvas.drawPoints(
            PointMode.polygon,
            cornerOffsets,
            Paint()
              ..color = isInside ? Colors.greenAccent.withOpacity(0.5) : Colors.amberAccent.withOpacity(0.5)
              ..strokeWidth = 4,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(BarcodeDetectorPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.barcodes != barcodes;
  }
}
