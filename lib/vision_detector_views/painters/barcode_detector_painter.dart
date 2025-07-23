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
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.amberAccent;

    final Paint background = Paint()..color = Colors.red;

    final double screenWidth = size.width;
    final double screenHeight = size.height;

    final double cropHeight = screenWidth < screenHeight
        ? screenHeight / (screenHeight > (screenHeight / 1.5) + 168 ? 1.5 : 2) + 56
        : screenHeight / 1.5;


    final double cropTopUI = (screenHeight - cropHeight) / 2;
    final double cropBottomUI = cropTopUI + cropHeight;

    final double boxTop = translateYInverse(
      cropTopUI,
      rotation,
      size,
      imageSize,
    );
    final double boxBottom = translateYInverse(
      cropBottomUI,
      rotation,
      size,
      imageSize,
    );

    // final Paint borderPaint = Paint()
    //   ..color = Colors.white.withOpacity(0.5)
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 2;
    //
    // canvas.drawRect(
    //   Rect.fromLTRB(0, cropTopUI, screenWidth, cropBottomUI),
    //   borderPaint,
    // );

    for (final Barcode barcode in barcodes) {
      final left = translateX(
        barcode.boundingBox.left,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final top = barcode.boundingBox.top;
      final right = translateX(
        barcode.boundingBox.right,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final bottom = barcode.boundingBox.bottom;


      if (top >= boxTop && bottom <= boxBottom) {
        final ParagraphBuilder builder = ParagraphBuilder(
          ParagraphStyle(
              textAlign: TextAlign.left,
              fontSize: 16,
              textDirection: TextDirection.ltr),
        );
        builder.pushStyle(
            ui.TextStyle(color: Colors.blue, background: background));
        // builder.addText('${barcode.displayValue}');
        builder.pop();

        final List<Offset> cornerPoints = <Offset>[];
        for (final point in barcode.cornerPoints) {
          final double x = translateX(
            point.x.toDouble(),
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          );
          final double y = translateY(
            point.y.toDouble(),
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          );

          cornerPoints.add(Offset(x, y));
        }

        // Add the first point to close the polygon
        cornerPoints.add(cornerPoints.first);
        canvas.drawPoints(PointMode.polygon, cornerPoints, paint);

        canvas.drawParagraph(
          builder.build()
            ..layout(ParagraphConstraints(
              width: (right - left).abs(),
            )),
          Offset(
              Platform.isAndroid &&
                      cameraLensDirection == CameraLensDirection.front
                  ? right
                  : left,
              top),
        );
        getScannedText(barcode);
      }
    }
  }

  @override
  bool shouldRepaint(BarcodeDetectorPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.barcodes != barcodes;
  }
}
