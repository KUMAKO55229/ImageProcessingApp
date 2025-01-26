import 'package:flutter/material.dart';
import 'package:image_processing_app/managers/image_manager.dart';
import 'package:image_processing_app/screens/image_processor_screen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ImageManager(),
      child: const ImageProcessingApp(),
    ),
  );
}

class ImageProcessingApp extends StatelessWidget {
  const ImageProcessingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[200],
      ),
      home: const ImageProcessorScreen(),
    );
  }
}
