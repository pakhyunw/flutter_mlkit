import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../gs1_parser.dart';
import 'detector_view.dart';
import 'painters/barcode_detector_painter.dart';
import 'painters/coordinates_translator.dart';

enum ScanMode { single, continuous, find, multi, ocr, ocrOnly }

class BarcodeScannerView extends StatefulWidget {
  final ScanMode mode;
  final Map<dynamic, Map<String, dynamic>> barcodeMapList;
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
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  var _cameraLensDirection = CameraLensDirection.back;
  
  List<Barcode> _currentBarcodes = [];
  List<Map<String, dynamic>> _currentParsedResults = []; 
  Size? _imageSize;
  InputImageRotation? _rotation;
  DateTime? _lastValidTime;

  // OCR 통합 모드용 스티키 타겟
  Map<String, dynamic>? _stickyOcrTarget;
  Rect? _stickyBarcodeRect;
  Map<String, dynamic> _persistentOcrData = {};

  final Set<String> _scannedCodes = {}; 
  final List<Map<String, dynamic>> _multiScanResults = []; 
  bool _isFinished = false;

  late Map<String, Map<String, dynamic>> _normalizedBarcodeMap;

  @override
  void initState() {
    super.initState();
    _normalizedBarcodeMap = widget.barcodeMapList.map(
      (key, value) => MapEntry(GS1Parser.normalizeGTIN(key.toString()), value)
    );
  }

  @override
  void dispose() {
    _canProcess = false;
    _barcodeScanner.close();
    _textRecognizer.close();
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
            receiver: StreamController(), 
            isContinue: widget.mode == ScanMode.continuous,
            onImage: _processImage,
            initialCameraLensDirection: _cameraLensDirection,
            onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
          ),
          _buildOverlayWidgets(context), // 항상 렌더링 시도
          if (widget.mode == ScanMode.multi && !_isFinished) _buildMultiScanButton(),
        ],
      ),
    );
  }

  Widget _buildOverlayWidgets(BuildContext context) {
    if (_imageSize == null || _rotation == null || _isFinished) return const SizedBox.shrink();

    final Size canvasSize = MediaQuery.of(context).size;
    List<Widget> overlays = [];

    // 1. 현재 인식 중인 바코드들 UI 생성
    for (int i = 0; i < _currentBarcodes.length; i++) {
      final barcode = _currentBarcodes[i];
      Map<String, dynamic> parsedData = (i < _currentParsedResults.length) 
          ? Map.from(_currentParsedResults[i]) 
          : GS1Parser.parse(barcode.rawValue ?? '');

      // OCR 정보가 있으면 보충
      if (widget.mode == ScanMode.ocr || widget.mode == ScanMode.ocrOnly) {
         parsedData['10'] ??= _persistentOcrData['10'];
         parsedData['17'] ??= _persistentOcrData['17'];
      }

      final double left = translateX(barcode.boundingBox.left, canvasSize, _imageSize!, _rotation!, _cameraLensDirection);
      final double top = translateY(barcode.boundingBox.top, canvasSize, _imageSize!, _rotation!, _cameraLensDirection);

      overlays.add(Positioned(
        left: left,
        top: top - 130, // 바코드 위쪽 적절한 위치
        child: widget.overlayWidgetBuilder(parsedData, widget.mode == ScanMode.find && _normalizedBarcodeMap.containsKey(parsedData['01'])),
      ));
    }

    // 2. 바코드는 놓쳤지만 스티키 데이터가 살아있는 경우 (통합 모드 전용)
    if (overlays.isEmpty && widget.mode == ScanMode.ocr && _stickyOcrTarget != null && _stickyBarcodeRect != null) {
       // 인식 유효 시간 체크 (800ms)
       if (_lastValidTime != null && DateTime.now().difference(_lastValidTime!).inMilliseconds < 800) {
          final Map<String, dynamic> data = Map.from(_stickyOcrTarget!);
          data['10'] ??= _persistentOcrData['10'];
          data['17'] ??= _persistentOcrData['17'];

          final double left = translateX(_stickyBarcodeRect!.left, canvasSize, _imageSize!, _rotation!, _cameraLensDirection);
          final double top = translateY(_stickyBarcodeRect!.top, canvasSize, _imageSize!, _rotation!, _cameraLensDirection);

          overlays.add(Positioned(
            left: left,
            top: top - 130,
            child: widget.overlayWidgetBuilder(data, false),
          ));
       }
    }

    return Stack(children: overlays);
  }

  Widget _buildMultiScanButton() {
    return Positioned(
      bottom: 100, left: 20, right: 20,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        onPressed: () {
          setState(() => _isFinished = true);
          if (widget.onComplete != null) widget.onComplete!(_multiScanResults);
        },
        child: Text('${_multiScanResults.length}개 스캔 완료', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _processImage(InputImage inputImage, bool isContinue) async {
    if (!_canProcess || _isBusy || _isFinished) return;
    _isBusy = true;

    try {
      final metadataSize = inputImage.metadata?.size;
      final metadataRotation = inputImage.metadata?.rotation;
      if (metadataSize == null || metadataRotation == null) return;

      _imageSize = metadataSize;
      _rotation = metadataRotation;

      List<Barcode> barcodes = [];
      if (widget.mode != ScanMode.ocrOnly) {
        barcodes = await _barcodeScanner.processImage(inputImage);
        if (barcodes.isEmpty && inputImage.bytes != null) {
          final invertedBytes = _fastInvertColors(inputImage.bytes!, inputImage.metadata);
          final invertedInputImage = InputImage.fromBytes(bytes: invertedBytes, metadata: inputImage.metadata!);
          barcodes = await _barcodeScanner.processImage(invertedInputImage);
        }
      }

      final Size canvasSize = MediaQuery.of(context).size;
      final bool isLandscape = canvasSize.width > canvasSize.height;
      final double roiBoxSize = (isLandscape ? canvasSize.height : canvasSize.width) * 0.5;
      final double roiLeft = (canvasSize.width - roiBoxSize) / 2;
      final double roiTop = (canvasSize.height - roiBoxSize) / 2;
      final double roiRight = roiLeft + roiBoxSize;
      final double roiBottom = roiTop + roiBoxSize;

      final bool useRoi = widget.mode != ScanMode.find && widget.mode != ScanMode.multi;

      // 1. OCR 엔진 분석
      if (widget.mode == ScanMode.ocr || widget.mode == ScanMode.ocrOnly) {
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            final double lLeft = translateX(line.boundingBox.left, canvasSize, metadataSize, metadataRotation, _cameraLensDirection);
            final double lTop = translateY(line.boundingBox.top, canvasSize, metadataSize, metadataRotation, _cameraLensDirection);
            if (lLeft >= roiLeft - 50 && lLeft <= roiRight + 50 && lTop >= roiTop - 50 && lTop <= roiBottom + 50) {
               Map<String, dynamic> ocrInfo = _extractInformationFromText(line.text);
               if (ocrInfo['pNumber'] != null) _persistentOcrData['10'] = ocrInfo['pNumber'];
               if (ocrInfo['expDate'] != null) _persistentOcrData['17'] = ocrInfo['expDate'];
            }
          }
        }
      }

      List<Barcode> validBarcodes = [];
      List<Map<String, dynamic>> parsedResults = [];

      // 2. 바코드 처리
      if (barcodes.isNotEmpty) {
        for (final barcode in barcodes) {
          final double left = translateX(barcode.boundingBox.left, canvasSize, metadataSize, metadataRotation, _cameraLensDirection);
          final double top = translateY(barcode.boundingBox.top, canvasSize, metadataSize, metadataRotation, _cameraLensDirection);
          final double right = translateX(barcode.boundingBox.right, canvasSize, metadataSize, metadataRotation, _cameraLensDirection);
          final double bottom = translateY(barcode.boundingBox.bottom, canvasSize, metadataSize, metadataRotation, _cameraLensDirection);
          
          bool isInside = !useRoi || (left >= roiLeft && right <= roiRight && top >= roiTop && bottom <= roiBottom);

          if (isInside) {
            validBarcodes.add(barcode);
            Map<String, dynamic> parsed = GS1Parser.parse(barcode.rawValue ?? '');
            if (widget.mode == ScanMode.ocr && parsed['01'] != null) {
               _stickyOcrTarget = parsed;
               _stickyBarcodeRect = barcode.boundingBox;
            }
            parsed['10'] ??= _persistentOcrData['10'];
            parsed['17'] ??= _persistentOcrData['17'];
            parsedResults.add(parsed);
          }
        }
      } else if (widget.mode == ScanMode.ocr || widget.mode == ScanMode.ocrOnly) {
        if (_persistentOcrData['10'] != null || _persistentOcrData['17'] != null) {
           final dummyBarcode = Barcode(
             boundingBox: Rect.fromLTWH(
               translateYInverse(roiTop + 100, metadataRotation, canvasSize, metadataSize), 
               translateXInverse(roiLeft + 100, metadataRotation, canvasSize, metadataSize), 
               50, 50
             ),
             rawValue: 'OCR_ONLY', displayValue: 'OCR', type: BarcodeType.unknown, format: BarcodeFormat.unknown, cornerPoints: [], rawBytes: Uint8List(0), value: null,
           );
           validBarcodes.add(dummyBarcode);
           parsedResults.add(Map.from(_persistentOcrData));
        }
      }

      _currentBarcodes = validBarcodes;
      _currentParsedResults = parsedResults;
      
      if (validBarcodes.isNotEmpty || _stickyOcrTarget != null) {
        _lastValidTime = DateTime.now();
      } else {
        if (_lastValidTime != null && DateTime.now().difference(_lastValidTime!).inMilliseconds > 1000) {
           _stickyOcrTarget = null;
           _stickyBarcodeRect = null;
           _persistentOcrData = {};
        }
      }

      _customPaint = CustomPaint(painter: BarcodeDetectorPainter(validBarcodes, metadataSize, metadataRotation, _cameraLensDirection, widget.mode));

      for (int i = 0; i < validBarcodes.length; i++) {
        final parsedData = parsedResults[i];
        bool isComplete = false;
        switch (widget.mode) {
          case ScanMode.single: isComplete = true; break;
          case ScanMode.ocr: isComplete = parsedData['01'] != null && parsedData['10'] != null && parsedData['17'] != null; break;
          case ScanMode.ocrOnly: isComplete = parsedData['10'] != null && parsedData['17'] != null; break;
          case ScanMode.continuous:
            final String raw = validBarcodes[i].rawValue ?? '';
            if (!_scannedCodes.contains(raw)) {
              _scannedCodes.add(raw);
              if (widget.onComplete != null) widget.onComplete!([parsedData]);
              Future.delayed(const Duration(seconds: 2), () => _scannedCodes.remove(raw));
            }
            break;
          default: break;
        }
        if (isComplete && !_isFinished) {
          setState(() => _isFinished = true);
          _canProcess = false;
          if (widget.onComplete != null) widget.onComplete!([parsedData]);
        }
      }
    } catch (e) {
      debugPrint("Process Error: $e");
    } finally {
      _isBusy = false;
      if (mounted) setState(() {});
    }
  }

  Uint8List _fastInvertColors(Uint8List bytes, InputImageMetadata? metadata) {
    final inverted = Uint8List.fromList(bytes);
    final int length = (metadata != null && (metadata.format == InputImageFormat.nv21 || metadata.format == InputImageFormat.yuv_420_888 || metadata.format == InputImageFormat.yuv420))
        ? metadata.size.width.toInt() * metadata.size.height.toInt() : bytes.length;
    final u64Length = length ~/ 8;
    final u64Data = Uint64List.view(inverted.buffer, 0, u64Length);
    for (int i = 0; i < u64Data.length; i++) u64Data[i] = ~u64Data[i];
    for (int i = u64Length * 8; i < length; i++) inverted[i] = 255 - inverted[i];
    return inverted;
  }

  Map<String, dynamic> _extractInformationFromText(String value) {
    String cleanText = value.replaceAll(RegExp('[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]'), ' ').replaceAll(RegExp(r'[/.\-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    Map<String, dynamic> body = _extractWithPatterns(cleanText);
    if (body['expDate'] == null) {
      String onlyDigits = cleanText.replaceAll(RegExp(r'\D'), '');
      if (onlyDigits.length >= 6) {
        String? extractedDate = _tryParseDate(onlyDigits);
        if (extractedDate != null) {
          body['expDate'] = extractedDate;
          body['pNumber'] ??= onlyDigits.replaceFirst(onlyDigits.substring(onlyDigits.length - 6), '').replaceAll(' ', '');
        }
      }
    }
    return body;
  }

  String? _tryParseDate(String digits) {
    if (digits.length >= 8) {
      String sub = digits.substring(digits.length - 8);
      try {
        DateTime dt = DateTime.parse('${sub.substring(0, 4)}-${sub.substring(4, 6)}-${sub.substring(6, 8)}');
        if (dt.year >= 2020 && dt.year <= 2045) return dt.toIso8601String().substring(0, 10);
      } catch (_) {}
    }
    if (digits.length >= 6) {
      String sub = digits.substring(digits.length - 6);
      try {
        DateTime dt = DateTime.parse('20${sub.substring(0, 2)}-${sub.substring(2, 4)}-${sub.substring(4, 6)}');
        return dt.toIso8601String().substring(0, 10);
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> _extractWithPatterns(String data) {
    String patternData = data.replaceAll(' ', '.');
    List<RegExp> patterns = [
      RegExp(r'([A-Z0-9]{4,})\.?(\d{4}\.\d{2}\.\d{2})'),
      RegExp(r'(\d{4}\.\d{2}\.\d{2})\.?([A-Z0-9]{4,})'),
      RegExp(r'(\d{2}\.\d{2}\.\d{2})\.?([A-Z0-9]{4,})'),
      RegExp(r'([A-Z0-9]{4,})\.?(\d{2}\.\d{2}\.\d{2})'),
    ];
    Map<String, dynamic> body = {'pNumber': null, 'expDate': null};
    RegExp d4 = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})');
    RegExp d2 = RegExp(r'(\d{2})\.(\d{2})\.(\d{2})');
    for (RegExp pattern in patterns) {
      final match = pattern.firstMatch(patternData);
      if (match != null) {
        for (int i = 1; i <= match.groupCount; i++) {
          String grp = match.group(i) ?? '';
          if (d4.hasMatch(grp)) body['expDate'] = grp.replaceAll('.', '-');
          else if (d2.hasMatch(grp)) body['expDate'] = '20${grp.replaceAll('.', '-')}';
          else if (grp.length >= 3) body['pNumber'] = grp;
        }
        break;
      }
    }
    return body;
  }
}
