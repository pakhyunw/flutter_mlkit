library flutter_mlkit;
import 'dart:async';

import 'package:flutter/material.dart';

import 'vision_detector_views/barcode_scanner_view.dart';

class FlutterMlkit {
  static Future<String> barcodeScan(context) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final StreamController receiver = StreamController();
      late BarcodeScannerView barcode = BarcodeScannerView(receiver: receiver, isContinue: false);
      var scannedText = '';
      Future.delayed(const Duration(milliseconds: 1000), () {
        receiver.stream.listen((message) {
          receiver.close();
          scannedText = message;
          Navigator.pop(context);
        });
      });
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return barcode;});
      return scannedText;
    } catch (e){
      return '';
    }

  }

  static Future<void> continuesBarcodeScan(context, StreamController receiver) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      late BarcodeScannerView barcode = BarcodeScannerView(receiver: receiver, isContinue: true);
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return barcode;});
    } catch (e){
      debugPrint(e.toString());
    }

  }
}
