// ─── upload_background.dart ───
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadBackground extends StatelessWidget {
  final Function(Uint8List) onImageSelected;
  final Uint8List? image;

  const UploadBackground({
    super.key,
    required this.onImageSelected,
    required this.image,
  });

  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final bytes = await file.readAsBytes();
      onImageSelected(bytes);
    }
  }

  Future<void> _pickFromCamera(BuildContext context, {required bool isFront}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: isFront ? CameraDevice.front : CameraDevice.rear,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      onImageSelected(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickFromGallery(context),
              icon: const Icon(Icons.image),
              label: const Text('Background'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _pickFromCamera(context, isFront: true),
              icon: Image.asset('assets/images/Camera.png', height: 32),
              tooltip: 'Camera (Front)',
            ),
            IconButton(
              onPressed: () => _pickFromCamera(context, isFront: false),
              icon: Image.asset('assets/images/Camera.png', height: 32),
              tooltip: 'Camera (Rear)',
            ),
          ],
        ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Image.memory(image!, height: 150),
          ),
      ],
    );
  }
}
