import 'package:flutter/material.dart';
import 'package:image_processing_app/managers/image_manager.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageProcessorScreen extends StatelessWidget {
  const ImageProcessorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final imageProvider = Provider.of<ImageManager>(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: ListView(
        children: [
          const SizedBox(height: 10),
          imageProvider.filteredImage == null
              ? imageProvider.imageFile == null
                  ? SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.file(imageProvider.imageFile!,
                          height: size.height * 0.4),
                    )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.memory(
                      Uint8List.fromList(
                          img.encodePng(imageProvider.filteredImage!)),
                      height: size.height * 0.4),
                ),
          Consumer<ImageManager>(
            builder: (BuildContext context, ImageManager imageManager,
                Widget? child) {
              return Padding(
                padding: EdgeInsets.symmetric(
                    vertical: 16, horizontal: size.width * 0.3),
                child: ElevatedButton(
                  onPressed: imageProvider.pickImage,
                  child: (imageProvider.imageFile == null &&
                          imageProvider.filteredImage == null)
                      ? const Text('Escolher Imagem')
                      : const Text('Trocar Imagem'),
                ),
              );
            },
          ),
          imageProvider.imageFile == null
              ? SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.01),
                  child: Slider(
                    value: imageProvider.filterIntensity,
                    min: 0.1,
                    max: 2.0,
                    divisions: 10,
                    label: imageProvider.filterIntensity.toStringAsFixed(1),
                    onChanged: (value) =>
                        imageProvider.setFilterIntensity(value),
                  ),
                ),
          imageProvider.imageFile == null
              ? SizedBox.shrink()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildColorButton(context, 'grayscale', Colors.grey),
                    _buildColorButton(context, 'red_channel', Colors.red),
                    _buildColorButton(context, 'green_channel', Colors.green),
                    _buildColorButton(context, 'blue_channel', Colors.blue),
                  ],
                ),
          imageProvider.imageFile == null
              ? SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: 16, horizontal: size.width * 0.2),
                  child: ElevatedButton(
                    onPressed: () =>
                        imageProvider.applyFilter('edge_detection'),
                    child: const Text('Detecção de Bordas'),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildColorButton(BuildContext context, String filter, Color color) {
    return ElevatedButton(
      onPressed: () =>
          Provider.of<ImageManager>(context, listen: false).applyFilter(filter),
      style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(16)),
      child: Container(),
    );
  }
}
