import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(ImageProcessingApp());
}

class ImageProcessingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ImageProcessorScreen(),
    );
  }
}

class ImageProcessorScreen extends StatefulWidget {
  @override
  _ImageProcessorScreenState createState() => _ImageProcessorScreenState();
}

class _ImageProcessorScreenState extends State<ImageProcessorScreen> {
  File? _image;
  img.Image? _filteredImage;

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
    await Isolate.spawn(_processImage, [image, filter, receivePort.sendPort]);

    final processedImage = await receivePort.first as img.Image;
    setState(() {
      _filteredImage = processedImage;
    });
  }

  static void _processImage(List<dynamic> args) {
    final img.Image image = args[0];
    final String filter = args[1];
    final SendPort sendPort = args[2];

    img.Image processedImage = img.Image.from(image);

    if (filter == 'grayscale') {
      processedImage = img.grayscale(image);
    } else if (filter == 'edge_detection') {
      processedImage = img.convolution(image,
          filter: [-1, -1, -1, -1, 8, -1, -1, -1, -1], div: 1);
    } else {
      for (int y = 0; y < processedImage.height; y++) {
        for (int x = 0; x < processedImage.width; x++) {
          final pixel = processedImage.getPixel(x, y);
          if (filter == 'red_channel') {
            processedImage.setPixel(
                x, y, img.ColorInt8.rgb(pixel.r.toInt(), 0, 0));
          } else if (filter == 'green_channel') {
            processedImage.setPixel(
                x, y, img.ColorInt8.rgb(0, pixel.g.toInt(), 0));
          } else if (filter == 'blue_channel') {
            processedImage.setPixel(
                x, y, img.ColorInt8.rgb(0, 0, pixel.b.toInt()));
          }
        }
      }
    }

    sendPort.send(processedImage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Processamento de Imagens')),
      body: ListView(
        // mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _image == null
              ? Text('Nenhuma imagem selecionada')
              : Image.file(_image!, height: 200),
          SizedBox(height: 10),
          _filteredImage == null
              ? Container()
              : Image.memory(Uint8List.fromList(img.encodePng(_filteredImage!)),
                  height: 200),
          SizedBox(height: 20),
          ElevatedButton(onPressed: _pickImage, child: Text('Escolher Imagem')),
          ElevatedButton(
              onPressed: () => _applyFilter('grayscale'),
              child: Text('Escala de Cinza')),
          SizedBox(width: 10),
          ElevatedButton(
              onPressed: () => _applyFilter('red_channel'),
              child: Text('Canal Vermelho')),
          SizedBox(width: 10),
          ElevatedButton(
              onPressed: () => _applyFilter('green_channel'),
              child: Text('Canal Verde')),
          SizedBox(width: 10),
          ElevatedButton(
              onPressed: () => _applyFilter('blue_channel'),
              child: Text('Canal Azul')),
          SizedBox(width: 10),
          ElevatedButton(
              onPressed: () => _applyFilter('edge_detection'),
              child: Text('Detecção de Bordas'))
        ],
      ),
    );
  }
}
