import 'dart:io';
import 'dart:isolate';
import 'package:image/image.dart' as img;

List<Map<String, dynamic>> subdivideImage(img.Image image) {
  final int numCores = Platform.numberOfProcessors;
  final int idealBlocks = (numCores * 2).clamp(2, 16);
  final int numRows = (image.height / 256).ceil().clamp(1, idealBlocks);
  final int numCols = (image.width / 256).ceil().clamp(1, idealBlocks);

  List<Map<String, dynamic>> blocks = [];
  int blockWidth = image.width ~/ numCols;
  int blockHeight = image.height ~/ numRows;

  for (int row = 0; row < numRows; row++) {
    for (int col = 0; col < numCols; col++) {
      int startX = col * blockWidth;
      int startY = row * blockHeight;
      int endX = (col == numCols - 1) ? image.width : (col + 1) * blockWidth;
      int endY = (row == numRows - 1) ? image.height : (row + 1) * blockHeight;

      img.Image block = img.copyCrop(image,
          x: startX, y: startY, width: endX - startX, height: endY - startY);
      blocks.add({'block': block, 'startX': startX, 'startY': startY});
    }
  }
  return blocks;
}

///  Processa um bloco da imagem em um Isolate
Future<img.Image> processImageInIsolate(
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

///  Processamento de imagem em um Isolate
void _processImage(List<dynamic> args) {
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
        block,
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

///  Junta os blocos processados na imagem final
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
