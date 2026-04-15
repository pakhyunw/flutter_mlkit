library flutter_mlkit;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import 'ocr/flutter_scalable_ocr.dart';
import 'vision_detector_views/barcode_scanner_view.dart' hide LangageScript;
export 'vision_detector_views/barcode_scanner_view.dart' show ScanMode, BarcodeScannerView;

class FlutterMlkit {
  /// Legacy scanner support (updated for the new view architecture)
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
      
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return BarcodeScannerView(
              mode: isContinue ? ScanMode.continuous : ScanMode.single,
              overlayWidgetBuilder: (parsedData, isTarget) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    parsedData.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                );
              },
              onComplete: (results) {
                for (var r in results) {
                   result(BarcodeScanResult(
                     message: r['01'] ?? r.values.first.toString(),
                     type: BarcodeType.unknown, // Simplified for legacy support
                     raw: r,
                     isContinue: isContinue,
                   ));
                }
                if (!isContinue) {
                  Navigator.pop(context);
                }
              },
            );
          });
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
  final BarcodeType type;
  final bool isContinue;
  final dynamic raw;

  BarcodeScanResult({required this.message, required this.type, required this.raw, required this.isContinue});
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
