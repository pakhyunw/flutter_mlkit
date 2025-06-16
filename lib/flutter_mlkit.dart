library flutter_mlkit;
import 'dart:async';

import 'package:flutter/material.dart';

import 'vision_detector_views/barcode_scanner_view.dart';

class FlutterMlkit {
  static Future<void> barcodeScan(context, Function result) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final StreamController<ScanResult> receiver = StreamController();
      late BarcodeScannerView barcode = BarcodeScannerView(receiver: receiver);
      var scannedText = '';
      Future.delayed(const Duration(milliseconds: 1000), () {
        receiver.stream.listen((ScanResult resultData) {
          if(!resultData.isContinue){
            receiver.close();
            result(resultData.message);
            Navigator.pop(context);
          } else {
            result(resultData.message);
          }
        });
      });
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return barcode;});
      receiver.close();

    } catch (e){
      debugPrint(e.toString());
    }
  }
}

class ScanResult {
  final String message;
  final bool isContinue;

  ScanResult({required this.message, required this.isContinue});
}