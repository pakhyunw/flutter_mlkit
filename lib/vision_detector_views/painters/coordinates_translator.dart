import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

double translateX(
  double x,
  Size canvasSize,
  Size imageSize,
  InputImageRotation rotation,
  CameraLensDirection cameraLensDirection,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x *
          canvasSize.width /
          (Platform.isIOS ? imageSize.width : imageSize.height);
    case InputImageRotation.rotation270deg:
      return canvasSize.width -
          x *
              canvasSize.width /
              (Platform.isIOS ? imageSize.width : imageSize.height);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      switch (cameraLensDirection) {
        case CameraLensDirection.back:
          return x * canvasSize.width / imageSize.width;
        default:
          return canvasSize.width - x * canvasSize.width / imageSize.width;
      }
  }
}

double translateY(
  double y,
  Size canvasSize,
  Size imageSize,
  InputImageRotation rotation,
  CameraLensDirection cameraLensDirection,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y *
          canvasSize.height /
          (Platform.isIOS ? imageSize.height : imageSize.width);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      return y * canvasSize.height / imageSize.height;
  }
}

double translateXInverse(
  double x,
  InputImageRotation rotation,
  Size canvasSize,
  Size imageSize,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x * (Platform.isIOS ? imageSize.width : imageSize.height) / canvasSize.width;
    case InputImageRotation.rotation270deg:
      return (canvasSize.width - x) * (Platform.isIOS ? imageSize.width : imageSize.height) / canvasSize.width;
    default:
      return x * imageSize.width / canvasSize.width;
  }
}

double translateYInverse(
  double y,
  InputImageRotation rotation,
  Size canvasSize,
  Size imageSize,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y * (Platform.isIOS ? imageSize.height : imageSize.width) / canvasSize.height;
    default:
      return y * imageSize.height / canvasSize.height;
  }
}
