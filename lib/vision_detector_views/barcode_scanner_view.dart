import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mlkit/flutter_mlkit.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;

import 'detector_view.dart';
import 'painters/barcode_detector_painter.dart';

class BarcodeScannerView extends StatefulWidget {
  BarcodeScannerView({
    super.key,
    required this.receiver,
    required this.isContinue,
    this.codeScanString,
    this.singleScanString,
    this.continuousScanString,
  });

  final StreamController<BarcodeScanResult> receiver;
  final bool isContinue;
  String? codeScanString;
  String? singleScanString;
  String? continuousScanString;

  @override
  BarcodeScannerViewState createState() => BarcodeScannerViewState();
}

class BarcodeScannerViewState extends State<BarcodeScannerView> {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;
  var _isScanned = false;
  late final StreamController<BarcodeScanResult> _receiver;
  final StreamController<BarcodeScanResult> _countReceiver = StreamController();

  bool _init = false;
  Set _results = {};

  @override
  void initState() {
    _receiver = widget.receiver;
    _text = '';
    _customPaint = null;
    super.initState();
  }

  @override
  void dispose() {
    _canProcess = false;
    _isScanned = false;
    _text = '';
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetectorView(
      title: 'Barcode Scanner',
      customPaint: _customPaint,
      receiver: _countReceiver,
      isContinue: widget.isContinue,
      codeScanString: widget.codeScanString,
      singleScanString: widget.singleScanString,
      continuousScanString: widget.continuousScanString,
      text: _text,
      onImage: _processImage,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    );
  }

  Future<void> _processImage(InputImage inputImage, bool isContinue) async {
    if (!_init) {
      _init = true;
      return;
    }
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;

    setState(() {
      _text = '';
    });

    // 1. Try scanning the original image
    var barcodes = await _barcodeScanner.processImage(inputImage);

    // 2. If no barcodes found, try scanning an inverted version (Fast fallback)
    if (barcodes.isEmpty) {
      final bytes = inputImage.bytes;
      if (bytes != null) {
        final invertedBytes = _fastInvertColors(bytes, inputImage.metadata);
        final invertedInputImage = InputImage.fromBytes(
          bytes: invertedBytes,
          metadata: inputImage.metadata!,
        );
        barcodes = await _barcodeScanner.processImage(invertedInputImage);
      } else if (inputImage.filePath != null) {
        final file = File(inputImage.filePath!);
        final imageBytes = await file.readAsBytes();
        final image = img.decodeImage(imageBytes);
        if (image != null) {
          img.invert(image);
          final jpgBytes = Uint8List.fromList(img.encodeJpg(image));
          final invertedPath = '${file.path}_inverted.jpg';
          await File(invertedPath).writeAsBytes(jpgBytes);
          final invertedInputImage = InputImage.fromFilePath(invertedPath);
          barcodes = await _barcodeScanner.processImage(invertedInputImage);
        }
      }
    }

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = BarcodeDetectorPainter(
        barcodes,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
        (Barcode barcode) {
          if (!_isScanned) {
            _canProcess = false;
            _isScanned = true;
            String code = barcode.displayValue ?? '';
            if (!_receiver.isClosed) {
              if (!_results.contains(code)) {
                _results.add(code);
                dynamic raw = barcode.value;
                switch (barcode.type) {
                  case BarcodeType.wifi:
                    raw = barcode.value as BarcodeWifi;
                    break;
                  case BarcodeType.url:
                    raw = barcode.value as BarcodeUrl;
                    break;
                  case BarcodeType.contactInfo:
                    raw = barcode.value as BarcodeContactInfo;
                    break;
                  case BarcodeType.email:
                    raw = barcode.value as BarcodeEmail;
                    break;
                  case BarcodeType.phone:
                    raw = barcode.value as BarcodePhone;
                    break;
                  case BarcodeType.sms:
                    raw = barcode.value as BarcodeSMS;
                    break;
                  case BarcodeType.geoCoordinates:
                    raw = barcode.value as BarcodeGeoPoint;
                    break;
                  case BarcodeType.calendarEvent:
                    raw = barcode.value as BarcodeCalenderEvent;
                    break;
                  case BarcodeType.driverLicense:
                    raw = barcode.value as BarcodeDriverLicense;
                    break;
                  default:
                    raw = barcode.value;
                }
                _receiver.add(BarcodeScanResult(
                    message: code,
                    isContinue: isContinue,
                    type: barcode.type,
                    raw: raw));
                _countReceiver.add(BarcodeScanResult(
                    message: code,
                    isContinue: isContinue,
                    type: barcode.type,
                    raw: raw));
              }
            }
            if (isContinue) {
              _canProcess = true;
              _isScanned = false;
            }
          }
        },
      );
      _customPaint = CustomPaint(painter: painter);
    } else {
      String text = 'Barcodes found: ${barcodes.length}\n\n';
      for (final barcode in barcodes) {
        text += 'Barcode: ${barcode.rawValue}\n\n';
        if (!_receiver.isClosed) {
          if (!_results.contains(barcode.rawValue)) {
            _results.add(barcode.rawValue);
            dynamic raw = barcode.value;
            switch (barcode.type) {
              case BarcodeType.wifi:
                raw = barcode.value as BarcodeWifi;
                break;
              case BarcodeType.url:
                raw = barcode.value as BarcodeUrl;
                break;
              case BarcodeType.contactInfo:
                raw = barcode.value as BarcodeContactInfo;
                break;
              case BarcodeType.email:
                raw = barcode.value as BarcodeEmail;
                break;
              case BarcodeType.phone:
                raw = barcode.value as BarcodePhone;
                break;
              case BarcodeType.sms:
                raw = barcode.value as BarcodeSMS;
                break;
              case BarcodeType.geoCoordinates:
                raw = barcode.value as BarcodeGeoPoint;
                break;
              case BarcodeType.calendarEvent:
                raw = barcode.value as BarcodeCalenderEvent;
                break;
              case BarcodeType.driverLicense:
                raw = barcode.value as BarcodeDriverLicense;
                break;
              default:
                raw = barcode.value;
            }
            _receiver.add(BarcodeScanResult(
                message: barcode.rawValue!, isContinue: isContinue, type: barcode.type, raw: raw));
            _countReceiver.add(BarcodeScanResult(
                message: barcode.rawValue!, isContinue: isContinue, type: barcode.type, raw: raw));
          }
        }
      }
      _text = text;
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Uint8List _fastInvertColors(Uint8List bytes, InputImageMetadata? metadata) {
    final inverted = Uint8List.fromList(bytes);
    final int length;

    // For YUV formats, we only need to invert the Y (Luminance) plane for barcode scanning
    if (metadata != null &&
        (metadata.format == InputImageFormat.nv21 ||
            metadata.format == InputImageFormat.yuv_420_888 ||
            metadata.format == InputImageFormat.yuv420)) {
      length = metadata.size.width.toInt() * metadata.size.height.toInt();
    } else {
      length = bytes.length;
    }

    // Optimization: Use Uint64List to process 8 bytes at a time
    final u64Length = length ~/ 8;
    final u64Data = Uint64List.view(inverted.buffer, 0, u64Length);
    for (int i = 0; i < u64Data.length; i++) {
      u64Data[i] = ~u64Data[i];
    }

    // Handle remaining bytes
    for (int i = u64Length * 8; i < length; i++) {
      inverted[i] = 255 - inverted[i];
    }

    return inverted;
  }
}

enum LangageScript{
  latin,
  chinese,
  devanagiri,
  japanese,
  korean,
}