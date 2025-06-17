library flutter_mlkit;
import 'dart:async';

import 'package:flutter/material.dart';

import 'vision_detector_views/barcode_scanner_view.dart';

class FlutterMlkit {
  static Future<void> barcodeScan(context, Function(BarcodeScanResult) result, {bool isContinue = false}) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final StreamController<BarcodeScanResult> receiver = StreamController();
      late BarcodeScannerView barcode = BarcodeScannerView(receiver: receiver, isContinue:isContinue);
      var scannedText = '';
      Future.delayed(const Duration(milliseconds: 1000), () {
        receiver.stream.listen((BarcodeScanResult resultData) {
          if(!resultData.isContinue){
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
            return barcode;});
      receiver.close();

    } catch (e){
      debugPrint(e.toString());
    }
  }
}

class BarcodeScanResult {
  final String message;
  final bool isContinue;

  BarcodeScanResult({required this.message, required this.isContinue});
}