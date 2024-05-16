import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'detector_view.dart';
import 'painters/barcode_detector_painter.dart';

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView(
      {super.key,
        required this.receiver});
  final StreamController receiver;

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
  late final StreamController _receiver;




  @override
  void initState(){
    _receiver = widget.receiver;
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
      text: _text,
      onImage: _processImage,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;

    setState(() {
      _text = '';
    });
    final barcodesOriginal = await _barcodeScanner.processImage(inputImage);
    List<Barcode> barcodes = [];
    if(barcodesOriginal.isEmpty){
      final imageBytes = inputImage.toJson()['bytes'];
      final invertedBytes = _invertColors(imageBytes);
      // Invert image colors
      final invertedInputImage = InputImage.fromBytes(
        bytes: invertedBytes,
        metadata: InputImageMetadata(
          size: inputImage.metadata?.size ?? Size(1024, 768),
          rotation: inputImage.metadata?.rotation ?? InputImageRotation.rotation0deg,
          format: inputImage.metadata?.format ?? InputImageFormat.nv21,
          bytesPerRow: inputImage.metadata?.bytesPerRow ?? 0,
        ),
      );

      // Process the inverted image
      final barcodesInverted = await _barcodeScanner.processImage(invertedInputImage);

      // Combine results from both images
      barcodes = barcodesInverted;
    } else {
      barcodes = barcodesOriginal;
    }
    barcodes = barcodes.isNotEmpty ? [barcodes[0]] : [];
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = BarcodeDetectorPainter(
        barcodes,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      _customPaint = CustomPaint(painter: painter);
      if(barcodes.isNotEmpty && !_isScanned){
        _canProcess = false;
        _isScanned = true;
        String code = '';
        for(Barcode barcode in barcodes){
          code += barcode.displayValue!;
        }
        _receiver.add(code);
      }

    } else {
      String text = 'Barcodes found: ${barcodes.length}\n\n';
      for (final barcode in barcodes) {
        text += 'Barcode: ${barcode.rawValue}\n\n';
      }
      _text = text;
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Uint8List _invertColors(Uint8List bytes) {
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 255 - bytes[i];
    }
    return bytes;
  }
}
