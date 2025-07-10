import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import '../services/click_image_helper.dart';

class ClickableMapImagePicker extends StatefulWidget {
  final void Function(Uint8List imageBytes, double latitude, double longitude) onImageReady;

  const ClickableMapImagePicker({super.key, required this.onImageReady});

  @override
  State<ClickableMapImagePicker> createState() => _ClickableMapImagePickerState();
}

class _ClickableMapImagePickerState extends State<ClickableMapImagePicker> {
  final ImagePicker _picker = ImagePicker();
  final loc.Location _location = loc.Location();

  Uint8List? _imageBytes;
  double? _latitude;
  double? _longitude;
  bool _loading = false;

  Future<void> _takePictureAndEmbedLocation() async {
    setState(() => _loading = true);

    try {
      // Check location permissions and get location
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          throw Exception('Location services disabled');
        }
      }

      final permissionGranted = await _location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        final permissionResult = await _location.requestPermission();
        if (permissionResult != loc.PermissionStatus.granted) {
          throw Exception('Location permission denied');
        }
      }

      final locationData = await _location.getLocation();

      // Pick image from camera
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile == null) throw Exception('No image captured');

      final bytes = await pickedFile.readAsBytes();

      // Embed clickable map icon & location metadata
      final embeddedImageBytes = await ClickImageHelper.embedLocationInImage(
        bytes,
        locationData.latitude!,
        locationData.longitude!,
      );

      setState(() {
        _imageBytes = embeddedImageBytes;
        _latitude = locationData.latitude;
        _longitude = locationData.longitude;
      });

      widget.onImageReady(_imageBytes!, _latitude!, _longitude!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_imageBytes != null)
          Stack(
            alignment: Alignment.topRight,
            children: [
              Image.memory(_imageBytes!),
              IconButton(
                icon: const Icon(Icons.map, color: Colors.blueAccent, size: 32),
                tooltip: 'Open location in map',
                onPressed: () {
                  if (_latitude != null && _longitude != null) {
                    ClickImageHelper.openMap(_latitude!, _longitude!);
                  }
                },
              ),
            ],
          )
        else if (_loading)
          const CircularProgressIndicator()
        else
          const Text('No image taken yet'),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take Picture with Location'),
          onPressed: _loading ? null : _takePictureAndEmbedLocation,
        ),
      ],
    );
  }
}