import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as imglib;

typedef HandleDetection = Future<dynamic> Function(InputImage image);
enum Choice { view, delete }

Future<CameraDescription> getCamera(CameraLensDirection dir) async {
  return await availableCameras().then(
        (List<CameraDescription> cameras) => cameras.firstWhere(
          (CameraDescription camera) => camera.lensDirection == dir,
    ),
  );
}

InputImage buildMetaData(CameraImage image, InputImageRotation rotation) {
  // Menggabungkan byte dari semua plane menjadi satu array byte
  final bytes = concatenatePlanes(image.planes);

  // Membuat metadata untuk InputImage
  final metadata = InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    format: InputImageFormat.nv21, // Menggunakan format default
    bytesPerRow: image.planes[0].bytesPerRow,
  );

  // Membuat InputImage dari byte dan metadata
  return InputImage.fromBytes(bytes: bytes, metadata: metadata);
}

/// Fungsi untuk menggabungkan byte dari semua plane gambar
Uint8List concatenatePlanes(List<Plane> planes) {
  final int totalBytes = planes.fold(0, (sum, plane) => sum + plane.bytes.length);
  final Uint8List allBytes = Uint8List(totalBytes);

  int offset = 0;
  for (Plane plane in planes) {
    allBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
    offset += plane.bytes.length;
  }

  return allBytes;
}

/// Detect objects in a given CameraImage.
Future<dynamic> detect(CameraImage image, HandleDetection handleDetection) async {
  try {
    // Mendapatkan rotasi kamera
    CameraDescription description = await getCamera(CameraLensDirection.front);
    InputImageRotation rotation = rotationIntToImageRotation(description.sensorOrientation);

    // Membuat InputImage
    final inputImage = buildMetaData(image, rotation);

    // Melakukan deteksi
    return await handleDetection(inputImage);
  } catch (e) {
    print('Error during detection: $e');
    return null;
  }
}

/// Convert an integer rotation value to an InputImageRotation enum.
InputImageRotation rotationIntToImageRotation(int rotation) {
  switch (rotation) {
    case 0:
      return InputImageRotation.rotation0deg;
    case 90:
      return InputImageRotation.rotation90deg;
    case 180:
      return InputImageRotation.rotation180deg;
    default:
      assert(rotation == 270);
      return InputImageRotation.rotation270deg;
  }
}

Float32List imageToByteListFloat32(
    imglib.Image image, int inputSize, double mean, double std) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = (imglib.getRed(pixel) - mean) / std;
      buffer[pixelIndex++] = (imglib.getGreen(pixel) - mean) / std;
      buffer[pixelIndex++] = (imglib.getBlue(pixel) - mean) / std;
    }
  }
  return convertedBytes.buffer.asFloat32List();
}

double euclideanDistance(List e1, List e2) {
  double sum = 0.0;
  for (int i = 0; i < e1.length; i++) {
    sum += pow((e1[i] - e2[i]), 2);
  }
  return sqrt(sum);
}