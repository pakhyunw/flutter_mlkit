import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../gs1_parser.dart';
import 'detector_view.dart';
import 'painters/barcode_detector_painter.dart';
import 'painters/coordinates_translator.dart';

enum ScanMode { single, continuous, find, multi }

class BarcodeScannerView extends StatefulWidget {
  final ScanMode mode;
  final Map<String, Map<String, dynamic>> barcodeMapList;
  final Widget Function(Map<String, dynamic> parsedData, bool isTarget) overlayWidgetBuilder;
  final Function(List<Map<String, dynamic>> results)? onComplete;

  BarcodeScannerView({
    super.key,
    required this.mode,
    this.barcodeMapList = const {},
    required this.overlayWidgetBuilder,
    this.onComplete,
  });

  @override
  BarcodeScannerViewState createState() => BarcodeScannerViewState();
}

class BarcodeScannerViewState extends State<BarcodeScannerView> {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  var _cameraLensDirection = CameraLensDirection.back;
  
  // Scanned barcodes state for AR overlays
  List<Barcode> _currentBarcodes = [];
  Size? _imageSize;
  InputImageRotation? _rotation;
  DateTime? _lastValidTime;

  // Internal state for modes
  final Set<String> _scannedCodes = {}; // For continuous mode debouncing
  final List<Map<String, dynamic>> _multiScanResults = []; // For multi mode
  bool _isFinished = false;

  @override
  void dispose() {
    _canProcess = false;
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          DetectorView(
            title: 'Barcode Scanner',
            customPaint: _customPaint,
            receiver: StreamController(), // Legacy
            isContinue: widget.mode == ScanMode.continuous || widget.mode == ScanMode.multi,
            onImage: _processImage,
            initialCameraLensDirection: _cameraLensDirection,
            onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
          ),
          if (!_isFinished) _buildOverlayWidgets(context),
          if (widget.mode == ScanMode.multi && !_isFinished) _buildMultiScanButton(),
        ],
      ),
    );
  }

  Widget _buildOverlayWidgets(BuildContext context) {
    // Keep UI visible for a short duration even if barcodes are temporarily lost
    bool isExpired = _lastValidTime != null && 
                     DateTime.now().difference(_lastValidTime!).inMilliseconds > 500;
                     
    if (_imageSize == null || _rotation == null || _currentBarcodes.isEmpty || (isExpired && _currentBarcodes.isNotEmpty)) {
      if (isExpired) {
        _currentBarcodes = [];
      }
      return const SizedBox.shrink();
    }

    final Size canvasSize = MediaQuery.of(context).size;

    return Stack(
      children: _currentBarcodes.map((barcode) {
        final double left = translateX(barcode.boundingBox.left, canvasSize, _imageSize!, _rotation!, _cameraLensDirection);
        final double top = translateY(barcode.boundingBox.top, canvasSize, _imageSize!, _rotation!, _cameraLensDirection);
        final double right = translateX(barcode.boundingBox.right, canvasSize, _imageSize!, _rotation!, _cameraLensDirection);
        final double bottom = translateY(barcode.boundingBox.bottom, canvasSize, _imageSize!, _rotation!, _cameraLensDirection);

        final String rawValue = barcode.rawValue ?? '';
        final Map<String, dynamic> parsedData = GS1Parser.parse(rawValue);
        final String gtin = parsedData['01'] ?? '';

        bool isTarget = false;
        if (widget.mode == ScanMode.find) {
           isTarget = widget.barcodeMapList.containsKey(gtin);
        }

        const double overlayWidth = 200;
        const double overlayHeight = 100;
        
        double posX = left;
        double posY = top - overlayHeight - 10;

        if (posY < 50) posY = bottom + 10; 
        if (posX + overlayWidth > canvasSize.width) posX = canvasSize.width - overlayWidth - 10;
        if (posX < 10) posX = 10;

        return Positioned(
          left: posX,
          top: posY,
          child: widget.overlayWidgetBuilder(parsedData, isTarget),
        );
      }).toList(),
    );
  }

  Widget _buildMultiScanButton() {
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: () {
          setState(() => _isFinished = true);
          if (widget.onComplete != null) {
            widget.onComplete!(_multiScanResults);
          }
        },
        child: Text(
          '${_multiScanResults.length}개 스캔 완료',
          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _processImage(InputImage inputImage, bool isContinue) async {
    if (!_canProcess || _isBusy || _isFinished) return;
    _isBusy = true;

    // 1. Try scanning original
    List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

    // 2. Invert fallback
    if (barcodes.isEmpty && inputImage.bytes != null) {
      final invertedBytes = _fastInvertColors(inputImage.bytes!, inputImage.metadata);
      final invertedInputImage = InputImage.fromBytes(
        bytes: invertedBytes,
        metadata: inputImage.metadata!,
      );
      barcodes = await _barcodeScanner.processImage(invertedInputImage);
    }

    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      final Size canvasSize = MediaQuery.of(context).size;
      final bool isLandscape = canvasSize.width > canvasSize.height;
      final double roiBoxSize = (isLandscape ? canvasSize.height : canvasSize.width) * 0.5;
      final double roiLeft = (canvasSize.width - roiBoxSize) / 2;
      final double roiTop = (canvasSize.height - roiBoxSize) / 2;
      final double roiRight = roiLeft + roiBoxSize;
      final double roiBottom = roiTop + roiBoxSize;

      final bool useRoi = widget.mode == ScanMode.single || widget.mode == ScanMode.continuous;

      // Filter
      List<Barcode> validBarcodes = [];
      for (final barcode in barcodes) {
        if (useRoi) {
          final double left = translateX(barcode.boundingBox.left, canvasSize, inputImage.metadata!.size, inputImage.metadata!.rotation, _cameraLensDirection);
          final double right = translateX(barcode.boundingBox.right, canvasSize, inputImage.metadata!.size, inputImage.metadata!.rotation, _cameraLensDirection);
          final double top = translateY(barcode.boundingBox.top, canvasSize, inputImage.metadata!.size, inputImage.metadata!.rotation, _cameraLensDirection);
          final double bottom = translateY(barcode.boundingBox.bottom, canvasSize, inputImage.metadata!.size, inputImage.metadata!.rotation, _cameraLensDirection);

          if (left >= roiLeft && right <= roiRight && top >= roiTop && bottom <= roiBottom) {
            validBarcodes.add(barcode);
          }
        } else {
          validBarcodes.add(barcode);
        }
      }

      // Update UI state only if we found something or after some time
      if (validBarcodes.isNotEmpty) {
        _currentBarcodes = validBarcodes;
        _imageSize = inputImage.metadata!.size;
        _rotation = inputImage.metadata!.rotation;
        _lastValidTime = DateTime.now();
        
        final painter = BarcodeDetectorPainter(
          barcodes,
          _imageSize!,
          _rotation!,
          _cameraLensDirection,
          widget.mode,
        );
        _customPaint = CustomPaint(painter: painter);
      } else {
        // If nothing found this frame, we don't clear immediately to avoid flickering
        // The _buildOverlayWidgets handles expiration.
        // But we update the painter to remove highlights of lost barcodes
        final painter = BarcodeDetectorPainter(
          [],
          inputImage.metadata!.size,
          inputImage.metadata!.rotation,
          _cameraLensDirection,
          widget.mode,
        );
        _customPaint = CustomPaint(painter: painter);
      }

      // Logic
      for (final barcode in validBarcodes) {
        final String rawValue = barcode.rawValue ?? '';
        final Map<String, dynamic> parsedData = GS1Parser.parse(rawValue);
        final String gtin = parsedData['01'] ?? '';

        switch (widget.mode) {
          case ScanMode.single:
            if (!_isFinished) {
              setState(() => _isFinished = true);
              _canProcess = false;
              if (widget.onComplete != null) {
                widget.onComplete!([parsedData]);
              }
            }
            break;
          case ScanMode.continuous:
            if (!_scannedCodes.contains(rawValue)) {
              _scannedCodes.add(rawValue);
              if (widget.onComplete != null) {
                widget.onComplete!([parsedData]);
              }
              Future.delayed(const Duration(seconds: 2), () {
                _scannedCodes.remove(rawValue);
              });
            }
            break;
          case ScanMode.find:
            if (widget.barcodeMapList.containsKey(gtin)) {
              if (!_isFinished) {
                setState(() => _isFinished = true);
                _canProcess = false;
                if (widget.onComplete != null) {
                  widget.onComplete!([parsedData]);
                }
              }
            }
            break;
          case ScanMode.multi:
            if (!_scannedCodes.contains(rawValue)) {
              _scannedCodes.add(rawValue);
              _multiScanResults.add(parsedData);
            }
            break;
        }
      }
    }

    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Uint8List _fastInvertColors(Uint8List bytes, InputImageMetadata? metadata) {
    final inverted = Uint8List.fromList(bytes);
    final int length;
    if (metadata != null &&
        (metadata.format == InputImageFormat.nv21 ||
            metadata.format == InputImageFormat.yuv_420_888 ||
            metadata.format == InputImageFormat.yuv420)) {
      length = metadata.size.width.toInt() * metadata.size.height.toInt();
    } else {
      length = bytes.length;
    }
    final u64Length = length ~/ 8;
    final u64Data = Uint64List.view(inverted.buffer, 0, u64Length);
    for (int i = 0; i < u64Data.length; i++) {
      u64Data[i] = ~u64Data[i];
    }
    for (int i = u64Length * 8; i < length; i++) {
      inverted[i] = 255 - inverted[i];
    }
    return inverted;
  }
}
