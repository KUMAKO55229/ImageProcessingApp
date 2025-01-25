import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const ImageProcessingApp());
}

class ImageProcessingApp extends StatelessWidget {
  const ImageProcessingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ImageProcessorScreen(),
    );
  }
}

class ImageProcessorScreen extends StatefulWidget {
  const ImageProcessorScreen({super.key});

  @override
  _ImageProcessorScreenState createState() => _ImageProcessorScreenState();
}

class _ImageProcessorScreenState extends State<ImageProcessorScreen> {
  File? _image;
  img.Image? _filteredImage;
  double _filterIntensity = 1.0;

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _applyFilter(String filter) async {
    if (_image == null) return;

    final bytes = await _image!.readAsBytes();
    final img.Image image = img.decodeImage(Uint8List.fromList(bytes))!;

    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(
        _processImage, [image, filter, _filterIntensity, receivePort.sendPort]);

    final processedImage = await receivePort.first as img.Image;
    setState(() {
      _filteredImage = processedImage;
    });
  }

  static void _processImage(List<dynamic> args) {
    final img.Image image = args[0];
    final String filter = args[1];
    final double intensity = args[2];
    final SendPort sendPort = args[3];

    img.Image processedImage = img.Image.from(image);

    switch (filter) {
      case 'grayscale':
        for (int y = 0; y < processedImage.height; y++) {
          for (int x = 0; x < processedImage.width; x++) {
            final pixel = processedImage.getPixel(x, y);
            int luminance =
                (((pixel.r * 0.3) + (pixel.g * 0.59) + (pixel.b * 0.11)) *
                        intensity)
                    .clamp(0, 255)
                    .toInt();
            processedImage.setPixel(
                x, y, img.ColorInt8.rgb(luminance, luminance, luminance));
          }
        }
        break;
      case 'edge_detection':
        processedImage = img.convolution(image,
            filter: [-1, -1, -1, -1, 8, -1, -1, -1, -1], div: 1);
        break;
      case 'red_channel':
      case 'green_channel':
      case 'blue_channel':
        for (int y = 0; y < processedImage.height; y++) {
          for (int x = 0; x < processedImage.width; x++) {
            final pixel = processedImage.getPixel(x, y);
            int r = (filter == 'red_channel' ? pixel.r * 0.3 * intensity : 0)
                .clamp(0, 255)
                .toInt();
            int g = (filter == 'green_channel' ? pixel.g * 0.59 * intensity : 0)
                .clamp(0, 255)
                .toInt();
            int b = (filter == 'blue_channel' ? pixel.b * 0.3 * intensity : 0)
                .clamp(0, 255)
                .toInt();

            processedImage.setPixel(x, y, img.ColorInt8.rgb(r, g, b));
          }
        }
        break;
    }
    sendPort.send(processedImage);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Processamento de Imagens')),
      body: ListView(
        children: [
          _image == null
              ? const Text('Nenhuma imagem selecionada')
              : Image.file(_image!, height: 200),
          const SizedBox(height: 10),
          _filteredImage == null
              ? Container()
              : Image.memory(Uint8List.fromList(img.encodePng(_filteredImage!)),
                  height: 200),
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: 16, horizontal: size.width * 0.3),
            child: ElevatedButton(
                onPressed: _pickImage, child: const Text('Escolher Imagem')),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.01),
            child: Slider(
              value: _filterIntensity,
              min: 0.1,
              max: 2.0,
              divisions: 10,
              label: _filterIntensity.toStringAsFixed(1),
              onChanged: (double value) {
                setState(() {
                  _filterIntensity = value;
                });
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _applyFilter('grayscale'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.all(16),
                ),
                child: Container(),
              ),
              ElevatedButton(
                onPressed: () => _applyFilter('red_channel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.all(16),
                ),
                child: Container(),
              ),
              ElevatedButton(
                onPressed: () => _applyFilter('green_channel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.all(16),
                ),
                child: Container(),
              ),
              ElevatedButton(
                onPressed: () => _applyFilter('blue_channel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.all(16),
                ),
                child: Container(),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: 16, horizontal: size.width * 0.2),
            child: ElevatedButton(
                onPressed: () => _applyFilter('edge_detection'),
                child: const Text('Detecção de Bordas')),
          ),
        ],
      ),
    );
  }
}
