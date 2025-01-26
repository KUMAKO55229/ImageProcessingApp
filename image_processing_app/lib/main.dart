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

    // 🔥 Divide a imagem em blocos e retorna uma lista de subimagens
    final List<Map<String, dynamic>> blocks = subdivideImage(image);

    List<Future<img.Image>> futures = [];
    List<ReceivePort> receivePorts =
        List.generate(blocks.length, (_) => ReceivePort());

    for (int i = 0; i < blocks.length; i++) {
      futures.add(_processImageInIsolate(
        blocks[i]['block'], // Passamos o bloco já recortado
        filter,
        _filterIntensity,
        blocks[i]['startX'],
        blocks[i]['startY'],
        receivePorts[i],
      ));
    }

    List<img.Image> processedParts = await Future.wait(futures);

    // 🔄 Recompõe a imagem com os blocos processados
    img.Image finalImage = img.Image(width: image.width, height: image.height);
    for (int i = 0; i < blocks.length; i++) {
      mergeImageRegion(finalImage, processedParts[i], blocks[i]['startX'],
          blocks[i]['startY']);
    }

    setState(() {
      _filteredImage = finalImage;
    });
  }

  /// 🔥 Função para dividir a imagem em blocos otimizados
  List<Map<String, dynamic>> subdivideImage(img.Image image) {
    final int numCores = Platform.numberOfProcessors;
    final int idealBlocks = (numCores * 2).clamp(2, 16);
    final int numRows = (image.height / 256).ceil().clamp(1, idealBlocks);
    final int numCols = (image.width / 256).ceil().clamp(1, idealBlocks);

    print("🔄 Subdividindo em $numRows linhas x $numCols colunas...");

    int blockWidth = image.width ~/ numCols;
    int blockHeight = image.height ~/ numRows;
    List<Map<String, dynamic>> blocks = [];

    for (int row = 0; row < numRows; row++) {
      for (int col = 0; col < numCols; col++) {
        int startX = col * blockWidth;
        int startY = row * blockHeight;
        int endX = (col == numCols - 1) ? image.width : (col + 1) * blockWidth;
        int endY =
            (row == numRows - 1) ? image.height : (row + 1) * blockHeight;

        img.Image block = img.copyCrop(image,
            x: startX, y: startY, width: endX - startX, height: endY - startY);
        blocks.add({'block': block, 'startX': startX, 'startY': startY});
      }
    }
    return blocks;
  }

  Future<img.Image> _processImageInIsolate(
    img.Image block,
    String filter,
    double intensity,
    int startX,
    int startY,
    ReceivePort receivePort,
  ) async {
    await Isolate.spawn(_processImage,
        [block, filter, intensity, startX, startY, receivePort.sendPort]);
    return await receivePort.first as img.Image;
  }

  static void _processImage(List<dynamic> args) {
    img.Image block = args[0];
    final String filter = args[1];
    final double intensity = args[2];
    final int startX = args[3];
    final int startY = args[4];
    final SendPort sendPort = args[5];

    switch (filter) {
      case 'grayscale':
        for (int y = 0; y < block.height; y++) {
          for (int x = 0; x < block.width; x++) {
            final pixel = block.getPixel(x, y);
            int luminance =
                (((pixel.r * 0.3) + (pixel.g * 0.59) + (pixel.b * 0.11)) *
                        intensity)
                    .clamp(0, 255)
                    .toInt();
            block.setPixel(
                x, y, img.ColorInt8.rgb(luminance, luminance, luminance));
          }
        }
        break;

      case 'edge_detection':
        block = img.convolution(
          block, // Agora a convolução é apenas no bloco!
          filter: [-1, -1, -1, -1, 8, -1, -1, -1, -1],
          div: 1,
        );
        break;

      case 'red_channel':
      case 'green_channel':
      case 'blue_channel':
        for (int y = 0; y < block.height; y++) {
          for (int x = 0; x < block.width; x++) {
            final pixel = block.getPixel(x, y);
            int r = (filter == 'red_channel' ? pixel.r * 0.3 * intensity : 0)
                .clamp(0, 255)
                .toInt();
            int g = (filter == 'green_channel' ? pixel.g * 0.59 * intensity : 0)
                .clamp(0, 255)
                .toInt();
            int b = (filter == 'blue_channel' ? pixel.b * 0.3 * intensity : 0)
                .clamp(0, 255)
                .toInt();

            block.setPixel(x, y, img.ColorInt8.rgb(r, g, b));
          }
        }
        break;
    }

    sendPort.send(block);
  }

  void mergeImageRegion(
      img.Image target, img.Image source, int startX, int startY) {
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        if (startX + x < target.width && startY + y < target.height) {
          target.setPixel(startX + x, startY + y, source.getPixel(x, y));
        }
      }
    }
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
              _buildColorButton('grayscale', Colors.grey),
              _buildColorButton('red_channel', Colors.red),
              _buildColorButton('green_channel', Colors.green),
              _buildColorButton('blue_channel', Colors.blue),
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

  Widget _buildColorButton(String filter, Color color) {
    return ElevatedButton(
      onPressed: () => _applyFilter(filter),
      style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(16)),
      child: Container(),
    );
  }
}
