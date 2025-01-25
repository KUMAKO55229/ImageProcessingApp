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

    img.Image processedImage;
    if (filter == 'grayscale') {
      processedImage = img.grayscale(image);
    } else if (filter == 'red_channel') {
      processedImage =
          img.copyResize(image, width: image.width, height: image.height);
      for (int y = 0; y < processedImage.height; y++) {
        for (int x = 0; x < processedImage.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = img.getLuminanceRgb(
              pixel.r.round(), pixel.g.round(), pixel.b.round());
          processedImage.setPixel(x, y, img.ColorInt8(r.toInt()));
        }
      }
    } else {
      processedImage = image;
    }

    sendPort.send(processedImage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Processamento de Imagens')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () => _applyFilter('grayscale'),
                  child: Text('Escala de Cinza')),
              SizedBox(width: 10),
              ElevatedButton(
                  onPressed: () => _applyFilter('red_channel'),
                  child: Text('Canal Vermelho')),
            ],
          )
        ],
      ),
    );
  }
}
