library flutter_mlkit;
import 'dart:async';

import 'package:flutter/material.dart';

import 'nlp_detector_views/entity_extraction_view.dart';
import 'nlp_detector_views/language_identifier_view.dart';
import 'nlp_detector_views/language_translator_view.dart';
import 'nlp_detector_views/smart_reply_view.dart';
import 'vision_detector_views/barcode_scanner_view.dart';
import 'vision_detector_views/digital_ink_recognizer_view.dart';
import 'vision_detector_views/face_detector_view.dart';
import 'vision_detector_views/face_mesh_detector_view.dart';
import 'vision_detector_views/label_detector_view.dart';
import 'vision_detector_views/object_detector_view.dart';
import 'vision_detector_views/pose_detector_view.dart';
import 'vision_detector_views/selfie_segmenter_view.dart';
import 'vision_detector_views/text_detector_view.dart';

class FlutterMlkit {
  static barcodeScan(context) async {
    late BuildContext barcodeContext;
    final StreamController receiver = StreamController();
    late BarcodeScannerView barcode = BarcodeScannerView(receiver: receiver);
    showDialog(
        context: context,
        builder: (BuildContext context) {
          barcodeContext = context;
      return barcode;});

    Future.delayed(Duration(milliseconds: 1000), () {
      receiver.stream.listen((message) {
        receiver.close();
        Navigator.pop(barcodeContext, message);
      });
    });
  }
}
