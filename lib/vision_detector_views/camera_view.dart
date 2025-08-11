import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';

import '../flutter_mlkit.dart';

class CameraView extends StatefulWidget {
  CameraView(
      {Key? key,
      required this.customPaint,
      required this.onImage,
      required this.receiver,
        required this.isContinue,
        this.codeScanString,
        this.singleScanString,
        this.continuousScanString,
      this.onCameraFeedReady,
      this.onDetectorViewModeChanged,
      this.onCameraLensDirectionChanged,
      this.initialCameraLensDirection = CameraLensDirection.back})
      : super(key: key);

  String? codeScanString;
  String? singleScanString;
  String? continuousScanString;

  final StreamController<BarcodeScanResult> receiver;
  final CustomPaint? customPaint;
  final bool isContinue;
  final Function(InputImage inputImage, bool isContinue) onImage;
  final VoidCallback? onCameraFeedReady;
  final VoidCallback? onDetectorViewModeChanged;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = -1;
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 3.0;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  bool _changingCameraLens = false;
  bool _flashStatus = false;
  bool _isContinueScan = false;
  int _scanCount = 0;
  File? _image;
  String? _path;
  ImagePicker? _imagePicker;
  bool _isGallery = false;
  bool? _isContinue;
  String codeScanString = '';
  String singleScanString = '';
  String continuousScanString = '';

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
    _isContinue = widget.isContinue;

    _initialize();
  }

  void _initialize() async {
    codeScanString = widget.codeScanString ?? '코드스캔';
    singleScanString = widget.singleScanString ?? '단일 스캔';
    continuousScanString = widget.continuousScanString ?? '연속 스캔';
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }

    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
        _cameraIndex = i;
        if(Platform.isAndroid) break;
        if(Platform.isIOS && _cameras[i].name.contains('built-in_video:5')){
          _cameraIndex = i;
          break;
        }
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
    widget.receiver.stream.listen((BarcodeScanResult resultData) {
      _scanCount++;
    });
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _liveFeedBody());
  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty) return Container();
    if (_controller == null) return Container();
    if (_controller?.value.isInitialized == false) return Container();

    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;


    return ColoredBox(
      color: Colors.black,
      child: Column(
        // alignment: Alignment.topCenter,
        // fit: StackFit.expand,
        children: <Widget>[
          Column(children: [

            Container(
                width: MediaQuery.of(context).size.width,
                color: Colors.black54,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    color: Colors.transparent,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _backButton(),
                          SizedBox(
                              height: 56,
                              child: Center(
                                  child: Text(
                                    codeScanString,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17),
                                  ))),
                          // _detectionViewModeToggle(),
                        ]),
                  ),
                )),
            Stack(
              alignment: AlignmentDirectional.center,
              children: [
                Center(
                  child: _changingCameraLens
                      ? Center(
                    child: const Text('Changing camera lens'),
                  )
                      : Container(
                    width: width,
                    height: width < height ? height / ( height > (height /1.5) + 168 ? 1.5 : 2) - 56 :  height / 1.5,
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover, // ✅ 중심 맞추고 위아래 잘라냄
                        child: SizedBox(
                          width: width > height ? _controller!.value.previewSize!.width : _controller!.value.previewSize!.height,
                          height: width < height ? _controller!.value.previewSize!.width : _controller!.value.previewSize!.height,
                          child: CameraPreview(
                            _controller!,
                            child: widget.customPaint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _flash(),
                _switchLiveCameraToggle(),
                _zoomControl(),
                _detectionViewModeToggle(),

              ],
            ),
          ],),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              _continueSwitch(),
              _countButton(),
            ],),
          ))
        ],
      ),
    );
  }

  Widget _backButton() => SizedBox(
        height: 50.0,
        width: 50.0,
        child: Icon(
          Icons.arrow_back_ios_outlined,
          color: Colors.white,
          size: 20,
        ),
      );

  Widget _detectionViewModeToggle() => Positioned(
        bottom: 20,
        child: GestureDetector(
          onTap: () => _getImage(ImageSource.gallery),
          child: Container(
            padding: EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: Colors.black38,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.photo_outlined,
                  color: Colors.white,
                  size: 25,
                ),
                Text(
                  '앨범',
                  style: TextStyle(color: Colors.white),
                )
              ],
            ),
          ),
        ),
      );

  Widget _flash() => Positioned(
        top: 10,
        right: 10,
        child: Container(
          height: 50.0,
          width: 50.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: Colors.black38,
          ),
          child: IconButton(
            onPressed: () => toggleFlash(),
            icon: Icon(
              _flashStatus ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
              size: 25,
            ),
          ),
        ),
      );

  toggleFlash() {
    setState(() {
      _flashStatus = !_flashStatus;
    });
    _controller?.setFlashMode(_flashStatus ? FlashMode.torch : FlashMode.off);
  }

  Widget _continueSwitch() => Visibility(
    visible: _isContinue ?? false,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: ()=>setState(() {_isContinueScan = false;}),
          child:  Container(
            color: Colors.transparent,
            child: Text(
              singleScanString,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Switch(
          value: _isContinueScan,
          activeColor: Colors.white,
          activeTrackColor: Colors.blue,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.grey,
          onChanged: (value) {
            setState(() {
              _isContinueScan = value;
            });
          },
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: ()=>setState(() {_isContinueScan = true;}),
          child: Container(
            color: Colors.transparent,
            child: Text(continuousScanString,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
      ],
    ),
  );

  Widget _switchLiveCameraToggle() => Visibility(
        visible: false,
        child: Positioned(
          bottom: 8,
          right: 8,
          child: SizedBox(
            height: 50.0,
            width: 50.0,
            child: FloatingActionButton(
              heroTag: Object(),
              onPressed: _switchLiveCamera,
              backgroundColor: Colors.black54,
              child: Icon(
                Platform.isIOS
                    ? Icons.flip_camera_ios_outlined
                    : Icons.flip_camera_android_outlined,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
        ),
      );

  Widget _zoomControl() => Visibility(
    visible: true,
    child: Positioned(
      right: 10,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotatedBox(
            quarterTurns: 3, // 90도 회전 (세로로)
            child: Slider(
              value: _currentZoomLevel,
              min: _minAvailableZoom,
              max: _maxAvailableZoom,
              activeColor: Colors.white,
              inactiveColor: Colors.white30,
              onChanged: (value) async {
                setState(() {
                  _currentZoomLevel = value;
                });
                await _controller?.setZoomLevel(value);
              },
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 50,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '${_currentZoomLevel.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _exposureControl() => Visibility(
        visible: false,
        child: Positioned(
          top: 40,
          right: 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 250,
            ),
            child: Column(children: [
              Container(
                width: 55,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(
                      '${_currentExposureOffset.toStringAsFixed(1)}x',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SizedBox(
                    height: 30,
                    child: Slider(
                      value: _currentExposureOffset,
                      min: _minAvailableExposureOffset,
                      max: _maxAvailableExposureOffset,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
                      onChanged: (value) async {
                        setState(() {
                          _currentExposureOffset = value;
                        });
                        await _controller?.setExposureOffset(value);
                      },
                    ),
                  ),
                ),
              )
            ]),
          ),
        ),
      );

  Future _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    print(_cameras);
    _controller = CameraController(
      camera,
      // Set to ResolutionPreset.high. Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.setFocusMode(FocusMode.auto);
      _controller?.getMinZoomLevel().then((value) {
        _currentZoomLevel = value;
        _minAvailableZoom = value;
      });
      // _controller?.getMaxZoomLevel().then((value) {
      //   _maxAvailableZoom = value;
      // });
      _currentExposureOffset = 0.0;
      _controller?.getMinExposureOffset().then((value) {
        _minAvailableExposureOffset = value;
      });
      _controller?.getMaxExposureOffset().then((value) {
        _maxAvailableExposureOffset = value;
      });
      _controller?.startImageStream(_processCameraImage).then((value) {
        if (widget.onCameraFeedReady != null) {
          widget.onCameraFeedReady!();
        }
        if (widget.onCameraLensDirectionChanged != null) {
          widget.onCameraLensDirectionChanged!(camera.lensDirection);
        }
      });
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;

    await _stopLiveFeed();
    await _startLiveFeed();
    setState(() => _changingCameraLens = false);
  }

  _countButton() {
    return Visibility(
      visible: _scanCount > 0,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
            height: 56,
            width: MediaQuery.of(context).size.width - 30,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(25.0),
            ),
            child: Center(
                child: Text(
              '$_scanCount개 스캔 완료',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ))),
      ),
    );
  }

  void _processCameraImage(CameraImage image) {
    if (_isGallery) return;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage, _isContinueScan);
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS


    if (Platform.isAndroid && format == InputImageFormat.yuv_420_888) {
      Uint8List nv21Data = convertYUV420ToNV21(image);
      return InputImage.fromBytes(
        bytes: nv21Data,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    } else if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
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




  Future _getImage(ImageSource source) async {
    _isGallery = true;
    setState(() {
      _image = null;
      _path = null;
    });
    final pickedFile = await _imagePicker?.pickImage(source: source);
    if (pickedFile != null) {
      _processFile(pickedFile.path);
    }
  }

  Future _processFile(String path) async {
    setState(() {
      _image = File(path);
    });
    _path = path;
    final inputImage = InputImage.fromFilePath(path);
    widget.onImage(inputImage, _isContinueScan);
    _isGallery = false;
  }
}
