import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mlkit/flutter_mlkit.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'detector_view.dart';
import 'painters/barcode_detector_painter.dart';

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key, required this.receiver});

  final StreamController<ScanResult> receiver;

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
  late final StreamController<ScanResult> _receiver;
  final StreamController<ScanResult> countReceiver = StreamController();
  bool _init = false;
  Set _results = {};


  @override
  void initState() {
    _receiver = widget.receiver;
    _text = '';
    _customPaint = null;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.initState();
  }

  @override
  void dispose() {
    _canProcess = false;
    _isScanned = false;
    _text = '';
    _barcodeScanner.close();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetectorView(
      title: 'Barcode Scanner',
      customPaint: _customPaint,
      receiver: countReceiver,
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

    final barcodesOriginal = await _barcodeScanner.processImage(inputImage);
    List<Barcode> barcodes = [];
    if (barcodesOriginal.isEmpty) {
      var imageBytes = inputImage.toJson()['bytes'];
      late InputImage invertedInputImage;
      if (imageBytes == null) {
        final file = File(inputImage.toJson()['path']);
        final imageBytes = await file.readAsBytes();
        final image = img.decodeImage(imageBytes);
        if (image == null) {
          print('Could not decode image.');
          return;
        }
        var invertedImage = img.invert(image);
        final jpgBytes = Uint8List.fromList(img.encodeJpg(invertedImage));
        final invertedPath = '${file.path}_inverted.jpg';
        final invertedFile = File(invertedPath);
        await invertedFile.writeAsBytes(jpgBytes);
        invertedInputImage =
            InputImage.fromFilePath('${file.path}_inverted.jpg');
      } else {
        final invertedBytes = _invertColors(imageBytes, inputImage.metadata);
        // Invert image colors
        invertedInputImage = InputImage.fromBytes(
          bytes: invertedBytes,
          metadata: InputImageMetadata(
            size: inputImage.metadata?.size ?? Size(1024, 768),
            rotation: inputImage.metadata?.rotation ??
                InputImageRotation.rotation0deg,
            format: inputImage.metadata?.format ?? InputImageFormat.nv21,
            bytesPerRow: inputImage.metadata?.bytesPerRow ?? 0,
          ),
        );
      }

      final barcodesInverted =
          await _barcodeScanner.processImage(invertedInputImage);

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
      if (barcodes.isNotEmpty && !_isScanned) {
        _canProcess = false;
        _isScanned = true;
        String code = '';
        for (Barcode barcode in barcodes) {
          code += barcode.displayValue!;
        }
        if(!_receiver.isClosed){
          if(!_results.contains(code)){
            _results.add(code);
            _receiver.add(ScanResult(message: code, isContinue: isContinue));
            countReceiver.add(ScanResult(message: code, isContinue: isContinue));
          }

        }
        if(isContinue){
          _canProcess = true;
          _isScanned = false;
        }
      }
    } else {
      String text = 'Barcodes found: ${barcodes.length}\n\n';
      for (final barcode in barcodes) {
        text += 'Barcode: ${barcode.rawValue}\n\n';
        if(!_receiver.isClosed){
          if(!_results.contains(barcode.rawValue)){
            _results.add(barcode.rawValue);
            _receiver.add(ScanResult(message: barcode.rawValue!, isContinue: isContinue));
            countReceiver.add(ScanResult(message: barcode.rawValue!, isContinue: isContinue));
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

  Uint8List _invertColors(Uint8List bytes, InputImageMetadata? metadata) {
    switch (metadata?.format) {
      case InputImageFormat.nv21:
        return _invertColorsNv21(bytes);
      case InputImageFormat.yv12:
        return _invertColorsYv12(bytes);
      case InputImageFormat.yuv_420_888:
        return _invertColorsYuv420888(
            bytes, metadata!.size.width.toInt(), metadata.size.height.toInt());
      case InputImageFormat.yuv420:
        return _invertColorsYuv420(
            bytes, metadata!.size.width.toInt(), metadata.size.height.toInt());
      case InputImageFormat.bgra8888:
      default:
        return _invertColorsBgra8888(bytes);
    }
  }

  Uint8List _invertColorsBgra8888(Uint8List bytes) {
    final length = bytes.length;
    final invertedBytes = Uint8List(length);
    for (int i = 0; i < length; i += 4) {
      invertedBytes[i] = 255 - bytes[i]; // B
      invertedBytes[i + 1] = 255 - bytes[i + 1]; // G
      invertedBytes[i + 2] = 255 - bytes[i + 2]; // R
      invertedBytes[i + 3] = bytes[i + 3]; // A (unchanged)
    }
    return invertedBytes;
  }

  Uint8List _invertColorsYuv420(Uint8List bytes, int width, int height) {
    final invertedBytes = Uint8List.fromList(bytes);
    final frameSize = width * height;

    // Invert Y values
    for (int i = 0; i < frameSize; i++) {
      invertedBytes[i] = 255 - invertedBytes[i];
    }

    // Invert UV values
    for (int i = frameSize; i < invertedBytes.length; i++) {
      invertedBytes[i] = 255 - invertedBytes[i];
    }

    return invertedBytes;
  }

  Uint8List _invertColorsYuv420888(Uint8List bytes, int width, int height) {
    final invertedBytes = Uint8List.fromList(bytes);
    final ySize = width * height;
    final uvSize = ySize ~/ 4;

    // Invert Y values
    for (int i = 0; i < ySize; i++) {
      invertedBytes[i] = 255 - invertedBytes[i];
    }

    // Invert U and V values
    for (int i = ySize; i < ySize + uvSize * 2; i++) {
      invertedBytes[i] = 255 - invertedBytes[i];
    }

    return invertedBytes;
  }

  Uint8List _invertColorsYv12(Uint8List bytes) {
    final invertedBytes = Uint8List.fromList(bytes);
    final frameSize = invertedBytes.length * 2 ~/ 3;

    // Invert Y values
    for (int i = 0; i < frameSize; i++) {
      invertedBytes[i] = 255 - invertedBytes[i];
    }

    // Invert VU values
    for (int i = frameSize; i < invertedBytes.length; i++) {
      invertedBytes[i] = 255 - invertedBytes[i];
    }

    return invertedBytes;
  }

  Uint8List _invertColorsNv21(Uint8List bytes) {
    final invertedBytes = Uint8List.fromList(bytes);
    final frameSize = invertedBytes.length * 2 ~/ 3;

    // Invert Y values
    for (int i = 0; i < frameSize; i++) {
      invertedBytes[i] = 255 - invertedBytes[i];
    }

    // Invert UV values
    for (int i = frameSize; i < invertedBytes.length; i++) {
      invertedBytes[i] = 255 - invertedBytes[i];
    }

    return invertedBytes;
  }
}
