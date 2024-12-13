import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Orientation Lock, Uint8List
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_cropper/image_cropper.dart';

void main() {
  runApp(MyImgProject());
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

class MyImgProject extends StatelessWidget {
  const MyImgProject({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "My Image Project",
      debugShowCheckedModeBanner: false,
      home: MyProjectUI(),
    );
  }
}

class MyProjectUI extends StatefulWidget {
  const MyProjectUI({super.key});

  @override
  State<MyProjectUI> createState() => _MyProjectUIState();
}

class _MyProjectUIState extends State<MyProjectUI> {
  // VARIABLES
  final ImagePicker _picker = ImagePicker();
  Uint8List? _originalColorImage;
  Uint8List? _originalImage;
  Uint8List? _processedImage;
  final TransformationController _transformationController =
      TransformationController();
  String _selectedOption = "Original Colors";
  TextEditingController _thresholdController = TextEditingController();
  int _threshold = 70;
  double _sharpeningValue = 0.0;
  double _smoothingValue = 0.0;

  @override
  void initState() {
    super.initState();
  }

  // Function to pick image from gallery
  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final imageBytes = await image.readAsBytes();
      setState(() {
        _originalColorImage = imageBytes;
        _processedImage = imageBytes; // Update the processed image
        _applySelectedOption(); // Refresh the image based on the selected option
      });
    }
  }

// Function to pick image from camera
  Future<void> _pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final imageBytes = await image.readAsBytes();
      setState(() {
        _originalColorImage = imageBytes;
        _processedImage = imageBytes; // Update the processed image
        _applySelectedOption(); // Refresh the image based on the selected option
      });
    }
  }

  // RESET ZOOM
  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  // RESTORE ORIGINAL COLORS
  void _restoreOriginalColors() {
    setState(() {
      _processedImage = _originalImage = _originalColorImage;
    });
  }

  // CONVERT TO NEGATIVE
  Uint8List? _convertToNegative(Uint8List imageData) {
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    final invertedImage = img.invert(image);
    return Uint8List.fromList(img.encodePng(invertedImage));
  }

  // CONVERT TO GRAYSCALE
  Uint8List? _convertToGrayscale(Uint8List imageData) {
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    final grayImage = img.grayscale(image);
    return Uint8List.fromList(img.encodePng(grayImage));
  }

  // CONVERT TO BINARY
  Uint8List? _convertToBinary(Uint8List imageData, int threshold) {
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);

        // Choose white or black based on threshold
        final binaryColor = luminance > threshold
            ? img.ColorRgb8(255, 255, 255)
            : img.ColorRgb8(0, 0, 0);
        image.setPixel(x, y, binaryColor);
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  // CONVERT TO INVERSE GRAYSCALE
  Uint8List? _convertToInverseGrayscale(Uint8List imageData) {
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    final grayImage = img.invert(img.grayscale(image));
    return Uint8List.fromList(img.encodePng(grayImage));
  }

  // CONVERT TO INVERSE BINARY
  Uint8List? _convertToInverseBinary(Uint8List imageData, int threshold) {
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);

        // Choose white or black based on threshold
        final binaryColor = luminance > threshold
            ? img.ColorRgb8(0, 0, 0)
            : img.ColorRgb8(255, 255, 255);
        image.setPixel(x, y, binaryColor);
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  /*
  // EROSION
  Uint8List? _applyErosion(Uint8List imageData, int kernelSize) {
    imageData = _convertToBinary(imageData, _threshold)!;
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    final erodedImage = img.copyResize(image); // Create a copy for output
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        int minValue = 255; // Start with the max luminance

        // Traverse the kernel
        for (int ky = -kernelSize ~/ 2; ky <= kernelSize ~/ 2; ky++) {
          for (int kx = -kernelSize ~/ 2; kx <= kernelSize ~/ 2; kx++) {
            final nx = x + kx;
            final ny = y + ky;

            // Ensure the pixel is within bounds
            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              final pixel = image.getPixel(nx, ny);
              final luminance = img.getLuminance(pixel);
              minValue =
                  luminance.toInt() < minValue ? luminance.toInt() : minValue;
            }
          }
        }

        // Set the pixel to the minimum value
        erodedImage.setPixel(x, y, img.ColorRgb8(minValue, minValue, minValue));
      }
    }

    return Uint8List.fromList(img.encodePng(erodedImage));
  }

  // DILATION
  Uint8List? _applyDilation(Uint8List imageData, int kernelSize) {
    imageData = _convertToBinary(imageData, _threshold)!;
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    final dilatedImage = img.copyResize(image); // Create a copy for output
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        int maxValue = 0; // Start with the min luminance

        // Traverse the kernel
        for (int ky = -kernelSize ~/ 2; ky <= kernelSize ~/ 2; ky++) {
          for (int kx = -kernelSize ~/ 2; kx <= kernelSize ~/ 2; kx++) {
            final nx = x + kx;
            final ny = y + ky;

            // Ensure the pixel is within bounds
            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              final pixel = image.getPixel(nx, ny);
              final luminance = img.getLuminance(pixel);
              maxValue =
                  luminance.toInt() > maxValue ? luminance.toInt() : maxValue;
            }
          }
        }

        // Set the pixel to the maximum value
        dilatedImage.setPixel(
            x, y, img.ColorRgb8(maxValue, maxValue, maxValue));
      }
    }

    return Uint8List.fromList(img.encodePng(dilatedImage));
  }

  // OPENING
  Uint8List? _applyOpening(Uint8List imageData, int kernelSize) {
    imageData = _convertToBinary(imageData, _threshold)!;
    final eroded = _applyErosion(imageData, kernelSize);
    if (eroded == null) return null;
    return _applyDilation(eroded, kernelSize);
  }

  // CLOSING
  Uint8List? _applyClosing(Uint8List imageData, int kernelSize) {
    imageData = _convertToBinary(imageData, _threshold)!;
    final dilated = _applyDilation(imageData, kernelSize);
    if (dilated == null) return null;
    return _applyErosion(dilated, kernelSize);
  }
  */

  // ROTATE IMAGE
  Uint8List? _rotateImage(Uint8List imageData, int degrees) {
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    final rotatedImage = img.copyRotate(image, angle: degrees);
    return Uint8List.fromList(img.encodePng(rotatedImage));
  }

  // APPLY SELECTED OPTION
  void _applySelectedOption() {
    if (_originalColorImage == null) return;

    setState(() {
      switch (_selectedOption) {
        case "Original Colors":
          _restoreOriginalColors();
          break;
        case "Negative":
          _processedImage =
              _originalImage = _convertToNegative(_originalColorImage!);
          break;
        case "Grayscale":
          _processedImage =
              _originalImage = _convertToGrayscale(_originalColorImage!);
          break;
        case "Inverse Grayscale":
          _processedImage =
              _originalImage = _convertToInverseGrayscale(_originalColorImage!);
          break;
        case "Binary":
          _processedImage = _originalImage =
              _convertToBinary(_originalColorImage!, _threshold);
          break;
        case "Inverse Binary":
          _processedImage = _originalImage =
              _convertToInverseBinary(_originalColorImage!, _threshold);
          break;
        /*
        case "Erosion":
          _processedImage = _originalImage =
              _applyErosion(_originalColorImage!, 3); // Kernel size = 3
          break;
        case "Dilation":
          _processedImage = _originalImage =
              _applyDilation(_originalColorImage!, 3); // Kernel size = 3
          break;
        case "Opening":
          _processedImage =
              _originalImage = _applyOpening(_originalColorImage!, 3);
          break;
        case "Closing":
          _processedImage =
              _originalImage = _applyClosing(_originalColorImage!, 3);
          break;
        */
      }
      _updateSharpeningValue(_sharpeningValue);
      _updateSmoothingValue(_smoothingValue);
    });
  }

  // APPLY SHARPENING
  Uint8List? _applySharpening(Uint8List imageData, double intensity) {
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    // Sharpening kernel with adjustable intensity
    final kernel = [
      0,
      -1,
      0,
      -1,
      4 + intensity.toInt(),
      -1,
      0,
      -1,
      0,
    ];

    img.convolution(
      image,
      filter: kernel,
      div: 1, // Keep raw sharpening strength
      offset: 0,
    );

    return Uint8List.fromList(img.encodePng(image));
  }

// APPLY SMOOTHING
  Uint8List? _applySmoothing(Uint8List imageData, double value) {
    final image = img.decodeImage(imageData);
    if (image == null) return null;

    img.gaussianBlur(image, radius: value.toInt());
    return Uint8List.fromList(img.encodePng(image));
  }

// UPDATE SHARP VALUE
  void _updateSharpeningValue(double value) {
    setState(() {
      _sharpeningValue = value;
      _applyEffects(); // Refresh image
    });
  }

// UPDATE SMOOTH VALUE
  void _updateSmoothingValue(double value) {
    setState(() {
      _smoothingValue = value;
      _applyEffects(); // Refresh image
    });
  }

// APPLY EFFECTS
  void _applyEffects() {
    if (_originalImage == null) return;

    Uint8List currentImage = _originalImage!;

    // Apply smoothing if active
    if (_smoothingValue > 0) {
      currentImage =
          _applySmoothing(currentImage, _smoothingValue) ?? currentImage;
    }

    // Apply sharpening if active
    if (_sharpeningValue == 1) {
      currentImage =
          _applySharpening(currentImage, _sharpeningValue) ?? currentImage;
    } else if (_sharpeningValue > 1) {
      currentImage =
          _applySharpening(currentImage, 1 + _sharpeningValue / 10) ??
              currentImage;
    }

    setState(() {
      _processedImage = currentImage;
    });
  }

  Future<void> _cropImage(Uint8List imageFile) async {
    try {
      // Save the image as a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_image.png');
      await tempFile.writeAsBytes(imageFile);

      // Crop the image using the temporary file path
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: tempFile.path, // Use the file path here
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.lightBlue,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false, // Unlock aspect ratio
            // aspectRatioPresets: [
            //   CropAspectRatioPreset.original,
            //   CropAspectRatioPreset.square,
            // ],
          ),
          WebUiSettings(
            context: context,
          ),
        ],
      );

      // Check if cropping was successful
      if (croppedFile != null) {
        final croppedImageBytes = await croppedFile.readAsBytes();
        setState(() {
          _processedImage = croppedImageBytes; // Set the cropped image
        });
      }
    } catch (e) {
      print("Error cropping image: $e");
    }
  }

  Future<void> _saveImage(Uint8List imageBytes) async {
    Directory? directory;
    if (Platform.isAndroid) {
      if (await _requestStoragePermission()) {
        directory =
            await getExternalStorageDirectory(); // App-specific directory
        String path = '${directory?.path}/Pictures';
        Directory(path)
            .createSync(recursive: true); // Ensure the directory exists

        File savedImage = File(
            'storage/emulated/0/Pictures/image_${DateTime.now().millisecondsSinceEpoch}.png');
        await savedImage.writeAsBytes(imageBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Image Saved Successfully in Internal Storage/Pictures"),
            duration:
                Duration(seconds: 3), // Duration the snackbar will be visible
          ),
        );
        print("Image saved successfully in Internal Storage/Pictures");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Storage permission denied"),
            duration:
                Duration(seconds: 3), // Duration the snackbar will be visible
          ),
        );
        print("Storage permission denied");
      }
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true; // Permission already granted
    } else if (await Permission.storage.request().isGranted) {
      return true; // Permission granted after request
    } else if (await Permission.manageExternalStorage.isGranted) {
      return true; // Special permission for Android 11+
    } else if (await Permission.manageExternalStorage.request().isGranted) {
      return true; // Special permission granted after request
    }
    // Permission denied
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Image Processing Project",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.lightBlue,
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _pickImageFromCamera,
                  icon: const Icon(Icons.camera_alt),
                ),
                const SizedBox(width: 10),
                // Button to pick image from gallery
                IconButton(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library),
                ),
                IconButton(
                  onPressed: _processedImage != null
                      ? () => _cropImage(_processedImage!)
                      : null,
                  icon: Icon(Icons.crop),
                ),
                IconButton(
                  onPressed: _processedImage != null
                      ? () {
                          if (_originalImage != null) {
                            final rotatedImg =
                                _rotateImage(_processedImage!, 90);
                            setState(() {
                              _processedImage = _originalImage = rotatedImg;
                            });
                          }
                        }
                      : null,
                  icon: Icon(Icons.rotate_90_degrees_cw),
                ),
                IconButton(
                  onPressed: _processedImage != null
                      ? () async {
                          _saveImage(_processedImage!);
                        }
                      : null,
                  icon: Icon(Icons.save),
                ),
              ],
            ),
            _processedImage != null
                ? InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: true, // Enable panning
                    minScale: 0.5, // Minimum zoom out scale
                    maxScale: 3.0, // Maximum zoom in scale
                    child: Image.memory(_processedImage!),
                  )
                : Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      "No Image Selected",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            SizedBox(height: 10),
            /*
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _resetZoom,
                  child: Text("Reset Zoom"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final rotatedImg = _rotateImage(_processedImage!, 90);
                    setState(() {
                      _processedImage = _originalImage = rotatedImg;
                    });
                  },
                  child: Text("Rotate 90°"),
                ),
              ],
            ),
            */
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _selectedOption,
                  items: [
                    "Original Colors",
                    "Negative",
                    "Grayscale",
                    "Inverse Grayscale",
                    "Binary",
                    "Inverse Binary",
                    /*
                    "Erosion",
                    "Dilation",
                    "Opening",
                    "Closing"
                    */
                  ]
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedOption = value!;
                    });
                    _applySelectedOption();
                  },
                ),
                SizedBox(height: 20),
                Visibility(
                  visible: _selectedOption == "Binary" ||
                      _selectedOption == "Inverse Binary",
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _thresholdController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Threshold",
                              ),
                            ),
                          ),
                          Text(
                            " %",
                            style: TextStyle(
                              fontSize: 20,
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              // Parse and apply the new threshold value
                              final newThreshold =
                                  double.tryParse(_thresholdController.text);
                              if (newThreshold != null &&
                                  newThreshold >= 0 &&
                                  newThreshold <= 100) {
                                setState(() {
                                  _threshold =
                                      (newThreshold * 255 / 100).toInt();
                                });
                                _applySelectedOption(); // Apply the effect with the updated threshold
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          "Please enter a valid percentage (0-100).")),
                                );
                              }
                            },
                            child: Text("Apply"),
                          ),
                        ],
                      ),
                      SizedBox(height: 15)
                    ],
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Text("Smoothing"),
                Slider(
                  value: _smoothingValue,
                  min: 0.0,
                  max: 10.0,
                  divisions: 10,
                  label: _smoothingValue.toStringAsFixed(1),
                  onChanged: _updateSmoothingValue,
                ),
                Text("Sharpening"),
                Slider(
                  value: _sharpeningValue,
                  min: 0.0,
                  max: 10.0,
                  divisions: 10,
                  label: _sharpeningValue.toStringAsFixed(1),
                  onChanged: _updateSharpeningValue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
