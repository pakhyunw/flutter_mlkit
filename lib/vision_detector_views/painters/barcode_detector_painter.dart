import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import 'coordinates_translator.dart';

double translateYInverse(
  double y,
  InputImageRotation rotation,
  Size size,
  Size absoluteImageSize,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return y * absoluteImageSize.width / size.height;
    case InputImageRotation.rotation270deg:
      return absoluteImageSize.width - (y * absoluteImageSize.width / size.height);
    default:
      return y * absoluteImageSize.height / size.height;
  }
}

class BarcodeDetectorPainter extends CustomPainter {
  BarcodeDetectorPainter(
    this.barcodes,
    this.imageSize,
    this.rotation,
    this.cameraLensDirection,
      this.getScannedText,
  );

  final List<Barcode> barcodes;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final Function getScannedText;


  @override
  void paint(Canvas canvas, Size size) {
    // Use size.width and size.height to determine orientation and ROI.
    final bool isLandscape = size.width > size.height;
    final double roiBoxSize = (isLandscape ? size.height : size.width) * 0.5;
    final double roiLeft = (size.width - roiBoxSize) / 2;
    final double roiTop = (size.height - roiBoxSize) / 2;
    final double roiRight = roiLeft + roiBoxSize;
    final double roiBottom = roiTop + roiBoxSize;

    final Paint roiPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const double cornerRadius = 15.0;

    final rrect = RRect.fromLTRBR(roiLeft, roiTop, roiRight, roiBottom, const Radius.circular(cornerRadius));

// 그림
    canvas.drawRRect(rrect, roiPaint);

    for (final Barcode barcode in barcodes) {
      // Translate barcode bounding box to canvas coordinates
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

      // Check if barcode is fully inside the ROI
      final bool isBarcodeInsideRoi = barcodeLeft >= roiLeft &&
          barcodeRight <= roiRight &&
          barcodeTop >= roiTop &&
          barcodeBottom <= roiBottom;

      if (isBarcodeInsideRoi) {
        getScannedText(barcode);

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
              ..color = Colors.amberAccent.withOpacity(0.5)
              ..strokeWidth = 4,
          );
        }

        // --- Test UI: Card display for EACH barcode ---
        final double cardWidth = 160;
        final double cardHeight = 70;

        // Position card above the barcode
        double cardX = barcodeLeft;
        double cardY = barcodeTop - cardHeight - 10;

        // Boundary check to keep card visible
        if (cardY < 10) cardY = barcodeBottom + 10; // Show below if no space above
        if (cardX + cardWidth > size.width) cardX = size.width - cardWidth - 10;
        if (cardX < 10) cardX = 10;

        final cardPaint = Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = Colors.amberAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        final cardRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cardX, cardY, cardWidth, cardHeight),
          const Radius.circular(8),
        );

        // Draw shadow for better visibility
        canvas.drawRRect(
          cardRect.shift(const Offset(2, 2)),
          Paint()
            ..color = Colors.black26
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );

        canvas.drawRRect(cardRect, cardPaint);
        canvas.drawRRect(cardRect, borderPaint);

        // Product Name
        final titlePainter = TextPainter(
          text: TextSpan(
            text: barcode.displayValue ?? 'Unknown',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        titlePainter.layout(maxWidth: cardWidth - 20);
        titlePainter.paint(canvas, Offset(cardX + 10, cardY + 10));

        // Type Info
        final infoPainter = TextPainter(
          text: TextSpan(
            text: barcode.type.name.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        infoPainter.layout();
        infoPainter.paint(canvas, Offset(cardX + 10, cardY + 30));

        // Status "CHECKED"
        final statusPainter = TextPainter(
          text: const TextSpan(
            text: '● SCANNED',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        statusPainter.layout();
        statusPainter.paint(canvas, Offset(cardX + 10, cardY + 50));
      }
    }
  }

  @override
  bool shouldRepaint(BarcodeDetectorPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.barcodes != barcodes;
  }
}
