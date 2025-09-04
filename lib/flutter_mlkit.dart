library flutter_mlkit;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
    Size? roiBoxSize,
    double? boxHeight,
    Function? getRawData,
    Paint? paintboxCustom,
    bool? torchOn,
    int cameraSelection = 0,
    bool lockCamera = true,
    bool? isLiveFeed,
    LanguageScript? languageScript,
  }) {
    return ScalableOCR(
      boxHeight:boxHeight,
      roiBoxSize: roiBoxSize,
      getScannedText: getScannedText,
      getRawData: getRawData,
      paintboxCustom: paintboxCustom,
      torchOn: torchOn,
      cameraSelection: cameraSelection,
      lockCamera: lockCamera,
      isLiveFeed: isLiveFeed,
      languageScript: languageScript,
    );
  }
}

class BarcodeScanResult {
  final String message;
  final bool isContinue;

  BarcodeScanResult({required this.message, required this.isContinue});
}

enum LanguageScript{
  latin,
  chinese,
  devanagiri,
  japanese,
  korean,
}

extension LanguageScriptExtension on LanguageScript {
  TextRecognitionScript get value {
    switch (this) {
      case LanguageScript.chinese:
        return TextRecognitionScript.chinese;
      case LanguageScript.devanagiri:
        return TextRecognitionScript.devanagiri;
      case LanguageScript.japanese:
        return TextRecognitionScript.japanese;
      case LanguageScript.korean:
        return TextRecognitionScript.korean;
      default:
        return TextRecognitionScript.latin;
    }
  }
}