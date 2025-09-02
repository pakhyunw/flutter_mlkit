
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../flutter_mlkit.dart';
import './text_recognizer_painter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';

class ScalableOCR extends StatefulWidget {
  const ScalableOCR(
      {super.key,
        this.roiBoxSize,
        this.boxHeight,
        required this.getScannedText,
        this.isLiveFeed,
        this.getRawData,
        this.paintboxCustom,
        this.cameraSelection = 0,
        this.torchOn,
        this.lockCamera = true,
        this.languageScript
      });

  final Size? roiBoxSize;

  /// Height of narrowed image
  final double? boxHeight;

  /// Function to get scanned text as a string
  final Function getScannedText;

  /// Get raw data from scanned image
  final Function? getRawData;

  /// Narrower box paint
  final Paint? paintboxCustom;

  /// Function to toggle torch
  final bool? torchOn;

  /// Camera Selection
  final int cameraSelection;

  /// Lock camera orientation
  final bool lockCamera;

  final bool? isLiveFeed;

  final LanguageScript? languageScript;

  @override
  ScalableOCRState createState() => ScalableOCRState();
}

class ScalableOCRState extends State<ScalableOCR> {
  late final TextRecognizer _textRecognizer;
  final cameraPrev = GlobalKey();
  final thePainter = GlobalKey();

  final bool _canProcess = true;
  bool _isBusy = false;
  bool converting = false;
  CustomPaint? customPaint;
  late bool _isLiveFeed;

  // String? _text;
  CameraController? _controller;
  late List<CameraDescription> _cameras;
  double zoomLevel = 3.0, minZoomLevel = 0.0, maxZoomLevel = 10.0;
  // Counting pointers (number of user fingers on screen)
  final double _minAvailableZoom = 1.0;
  final double _maxAvailableZoom = 10.0;
  double _currentScale = 3.0;
  double _baseScale = 3.0;
  double maxWidth = 0;
  double maxHeight = 0;
  String convertingAmount = "";

  @override
  void initState() {
    super.initState();
    _isLiveFeed = widget.isLiveFeed ?? true;
    _textRecognizer = TextRecognizer(script: widget.languageScript?.value ?? LanguageScript.latin.value);
    startLiveFeed();
  }

  @override
  void dispose() {
    stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double sizeH = MediaQuery.of(context).size.height / 100;
    return _controller == null ||
        _controller?.value == null ||
        _controller?.value.isInitialized == false
        ? Container(
      width: MediaQuery.of(context).size.width,
      height: widget.boxHeight ?? sizeH * 19,
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(17),
      ),
    )
        : _liveFeedBody();
  }

  // Body of live camera stream
  Widget _liveFeedBody() {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Text('Tap a camera');
    } else {
      const double previewAspectRatio = 0.5;
      return SizedBox(
        height: widget.boxHeight ?? MediaQuery.of(context).size.height / 5,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Center(
              child: SizedBox(
                height: widget.boxHeight ?? MediaQuery.of(context).size.height / 5,
                width: MediaQuery.of(context).size.width,
                key: cameraPrev,
                child: ClipRRect(
                  borderRadius:
                  const BorderRadius.all(Radius.circular(16.0)),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      height: _controller!.value.previewSize!.width,
                      width: _controller!.value.previewSize!.height,
                      child: CameraPreview(cameraController, child: customPaint),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // Start camera stream function
  Future startLiveFeed() async {
    _cameras = await availableCameras();
    final camera = _cameras[widget.cameraSelection];

    _controller = CameraController(
      camera,
      ResolutionPreset.high,   // high 만 사용
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21 // for Android
          : ImageFormatGroup.bgra8888, // for iOS
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      if (widget.lockCamera == true) {
        _controller?.lockCaptureOrientation();
      } else {
        _controller?.unlockCaptureOrientation();
      }

      _controller?.setFocusMode(FocusMode.auto);
      _controller?.setZoomLevel(2.0);


      if (_controller != null) {
        if (widget.torchOn != null) {
          if (widget.torchOn == true) {
            _controller!.setFlashMode(FlashMode.torch);
          } else {
            _controller!.setFlashMode(FlashMode.off);
          }
        }
      }

      _controller?.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            log('User denied camera access.');
            break;
          default:
            log('Handle other errors.');
            break;
        }
      }
    });
  }

  // Process image from camera stream
  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  Future _processCameraImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
    Size(image.width.toDouble(), image.height.toDouble());

    final camera = _cameras[0];

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? imageRotation;
    if (Platform.isIOS) {
      imageRotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      imageRotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (imageRotation == null) return null;

    // get image format
    final imageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (Platform.isAndroid && imageFormat == InputImageFormat.yuv_420_888) {
      Uint8List nv21Data = convertYUV420ToNV21(image);
    final inputImage = InputImage.fromBytes(
        bytes: nv21Data,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: imageRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
      processImage(inputImage);
      return;
    } else if (imageFormat == null ||
        (Platform.isAndroid && imageFormat != InputImageFormat.nv21) ||
        (Platform.isIOS && imageFormat != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;

    final planeData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: imageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    final inputImage =
    // InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    InputImage.fromBytes(bytes: bytes, metadata: planeData);

    processImage(inputImage);
  }

  Uint8List convertYUV420ToNV21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    // Planes from CameraImage
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // Buffers from Y, U, and V planes
    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    // Total number of pixels in NV21 format
    final numPixels = width * height + (width * height ~/ 2);
    final nv21 = Uint8List(numPixels);

    // Y (Luma) plane metadata
    int idY = 0;
    int idUV = width * height; // Start UV after Y plane
    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;

    // Strides and pixel strides for Y and UV planes
    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 2;

    // Copy Y (Luma) channel
    for (int y = 0; y < height; ++y) {
      final yOffset = y * yRowStride;
      for (int x = 0; x < width; ++x) {
        nv21[idY++] = yBuffer[yOffset + x * yPixelStride];
      }
    }

    // Copy UV (Chroma) channels in NV21 format (YYYYVU interleaved)
    for (int y = 0; y < uvHeight; ++y) {
      final uvOffset = y * uvRowStride;
      for (int x = 0; x < uvWidth; ++x) {
        final bufferIndex = uvOffset + (x * uvPixelStride);
        nv21[idUV++] = vBuffer[bufferIndex]; // V channel
        nv21[idUV++] = uBuffer[bufferIndex]; // U channel
      }
    }

    return nv21;
  }


  // Scale image
  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  // Handle scale update
  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (_controller == null) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    await _controller!.setZoomLevel(_currentScale);
  }

  // Focus image
  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (_controller == null) {
      return;
    }

    final CameraController cameraController = _controller!;

    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  // Stop camera live stream
  Future stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  // Process image
  Future<void> processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;

    final recognizedText = await _textRecognizer.processImage(inputImage);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null &&
        cameraPrev.currentContext != null) {
      final RenderBox renderBox =
      cameraPrev.currentContext?.findRenderObject() as RenderBox;

      var painter = TextRecognizerPainter(
          recognizedText,
          inputImage.metadata!.size,
          inputImage.metadata!.rotation,
          renderBox, (value) {
        widget.getScannedText(value);
      }, CameraLensDirection.back,
      isLiveFeed: _isLiveFeed,  getRawData: (value) {
        if (widget.getRawData != null) {
          widget.getRawData!(value);
        }
      },
          roiBoxSize: widget.roiBoxSize,
          paintboxCustom: widget.paintboxCustom);

      customPaint = CustomPaint(painter: painter);
    } else {
      customPaint = null;
    }
    Future.delayed(const Duration(milliseconds: 900)).then((value) {
      if (!converting) {
        _isBusy = false;
      }

      if (mounted) {
        setState(() {});
      }
    });
  }


}

