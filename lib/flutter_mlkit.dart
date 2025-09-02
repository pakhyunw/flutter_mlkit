library flutter_mlkit;

import 'dart:async';

import 'package:flutter/material.dart';

import 'ocr/flutter_scalable_ocr.dart';
import 'vision_detector_views/barcode_scanner_view.dart' hide LangageScript;

class FlutterMlkit {
  static Future<void> barcodeScan(
    context,
    Function(BarcodeScanResult) result, {
    bool isContinue = false,
    String? codeScanString,
    String? singleScanString,
    String? continuousScanString,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final StreamController<BarcodeScanResult> receiver = StreamController();
      late BarcodeScannerView barcode = BarcodeScannerView(
        receiver: receiver,
        isContinue: isContinue,
        codeScanString: codeScanString,
        singleScanString: singleScanString,
        continuousScanString: continuousScanString,
      );
      var scannedText = '';
      Future.delayed(const Duration(milliseconds: 1000), () {
        receiver.stream.listen((BarcodeScanResult resultData) {
          if (!resultData.isContinue) {
            receiver.close();
            result(resultData);
            Navigator.pop(context);
          } else {
            result(resultData);
          }
        });
      });
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return barcode;
          });
      receiver.close();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  static Widget scalableOCR({
    required Function getScannedText,
    double boxLeftOff = 4,
    double boxRightOff = 4,
    double boxBottomOff = 2.7,
    double boxTopOff = 2.7,
    double? boxHeight,
    Function? getRawData,
    Paint? paintboxCustom,
    bool? torchOn,
    int cameraSelection = 0,
    bool lockCamera = true,
    bool? isLiveFeed,
    LangageScript? langageScript,
  }) {
    return ScalableOCR(
      boxLeftOff: boxLeftOff,
      boxRightOff: boxRightOff,
      boxBottomOff: boxBottomOff,
      boxTopOff: boxTopOff,
      boxHeight: boxHeight,
      getScannedText: getScannedText,
      getRawData: getRawData,
      paintboxCustom: paintboxCustom,
      torchOn: torchOn,
      cameraSelection: cameraSelection,
      lockCamera: lockCamera,
      isLiveFeed: isLiveFeed,
      langageScript: langageScript,
    );
  }
}

class BarcodeScanResult {
  final String message;
  final bool isContinue;

  BarcodeScanResult({required this.message, required this.isContinue});
}
