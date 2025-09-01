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
      final bool isBarcodeInsideRoi =
          barcodeLeft >= roiLeft &&
          barcodeRight <= roiRight &&
          barcodeTop >= roiTop &&
          barcodeBottom <= roiBottom;

      if (isBarcodeInsideRoi) {
        getScannedText(barcode);
        // Draw barcode corners
        final List<Offset> cornerOffsets = barcode.cornerPoints.map((point) {
          return Offset(
            translateX(point.x.toDouble(), size, imageSize, rotation, cameraLensDirection),
            translateY(point.y.toDouble(), size, imageSize, rotation, cameraLensDirection),
          );
        }).toList();
        if (cornerOffsets.isNotEmpty) {
          // Close the polygon
          cornerOffsets.add(cornerOffsets.first);
          canvas.drawPoints(
            PointMode.polygon,
            cornerOffsets,
            Paint()
              ..color = Colors.amberAccent
              ..strokeWidth = 3,
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
