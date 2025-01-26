import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:image_processing_app/managers/utils/image_utils.dart';

class ImageManager extends ChangeNotifier {
  File? _imageFile;
  img.Image? _filteredImage;
  double _filterIntensity = 1.0;
  bool _isProcessing = false;

  File? get imageFile => _imageFile;
  img.Image? get filteredImage => _filteredImage;
  double get filterIntensity => _filterIntensity;
  bool get isProcessing => _isProcessing;

  /// Atualiza a intensidade do filtro
  void setFilterIntensity(double value) {
    _filterIntensity = value;
    notifyListeners();
  }

  /// Método para selecionar a imagem
  Future<void> pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _imageFile = File(pickedFile.path);
      _filteredImage = null;
      notifyListeners();
    }
  }

  /// Aplica o filtro com processamento paralelo
  Future<void> applyFilter(String filter) async {
    if (_imageFile == null) return;

    _isProcessing = true;
    notifyListeners();

    final bytes = await _imageFile!.readAsBytes();
    final img.Image image = img.decodeImage(Uint8List.fromList(bytes))!;

    final List<Map<String, dynamic>> blocks = subdivideImage(image);
    List<Future<img.Image>> futures = [];
    List<ReceivePort> receivePorts =
        List.generate(blocks.length, (_) => ReceivePort());

    for (int i = 0; i < blocks.length; i++) {
      futures.add(processImageInIsolate(
        blocks[i]['block'],
        filter,
        _filterIntensity,
        blocks[i]['startX'],
        blocks[i]['startY'],
        receivePorts[i],
      ));
    }

    List<img.Image> processedParts = await Future.wait(futures);

    //  Recompõe a imagem com os blocos processados
    img.Image finalImage = img.Image(width: image.width, height: image.height);
    for (int i = 0; i < blocks.length; i++) {
      mergeImageRegion(finalImage, processedParts[i], blocks[i]['startX'],
          blocks[i]['startY']);
    }

    _filteredImage = finalImage;
    _isProcessing = false;
    notifyListeners();
  }
}
