import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_media_store/flutter_media_store.dart';
import '../services/image_processor.dart';
import 'package:location/location.dart' as loc;
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Enum for user theme preference
enum UserTheme { barbie, traveller }

class HomeController extends ChangeNotifier {
  Uint8List? fgBytes, bgBytes, blendedBytes, outBytes;
  String userText = '';
  String watermarkText = '';
  bool isLoading = false, livePreview = false;

  // Location
  double? latitude;
  double? longitude;
  bool isLocationSet = false;
  final loc.Location _location = loc.Location();

  final picker = ImagePicker();

  // Theme preference
  UserTheme selectedTheme = UserTheme.barbie;

  void setTheme(UserTheme theme) {
    selectedTheme = theme;
    notifyListeners();
  }

  // Setters
  void setForeground(Uint8List bytes) {
    fgBytes = bytes;
    notifyListeners();
  }

  void setBackground(Uint8List bytes) {
    bgBytes = bytes;
    notifyListeners();
  }

  void setText(String text) {
    userText = text;
    notifyListeners();
  }

  void setWatermarkText(String text) {
    watermarkText = text;
    notifyListeners();
  }

  void toggleLivePreview(bool value) {
    livePreview = value;
    notifyListeners();
  }

  void resetAll() {
    fgBytes = null;
    bgBytes = null;
    blendedBytes = null;
    outBytes = null;
    userText = '';
    watermarkText = '';
    livePreview = false;
    latitude = null;
    longitude = null;
    isLocationSet = false;
    notifyListeners();
  }

  /* ─────────────── LOCATION + MAP ─────────────── */

  Future<void> getLocation(BuildContext context) async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        _showSnackbar(context, '❌ Location services are disabled.');
        return;
      }
    }

    loc.PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        _showSnackbar(context, '❌ Location permission denied.');
        return;
      }
    }

    final locationData = await _location.getLocation();
    latitude = locationData.latitude;
    longitude = locationData.longitude;
    isLocationSet = true;

    _showSnackbar(context, '📍 Location set: ($latitude, $longitude)');
    notifyListeners();
  }

  Future<void> openInGoogleMaps(BuildContext context) async {
    if (latitude == null || longitude == null) return;

    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$latitude,$longitude");

    if (await launcher.canLaunchUrl(url)) {
      await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
    } else {
      _showSnackbar(context, '❌ Could not open Google Maps.');
    }
  }

  /* ─────────────── STORAGE ─────────────── */

  Future<bool> _requestStoragePermission() async {
    if (await Permission.photos.request().isGranted) return true;
    if (await Permission.storage.request().isGranted) return true;
    return false;
  }

  /* ─────────────── IMAGE CREATION ─────────────── */

  Future<void> createImage(BuildContext context, {String? theme}) async {
    if (fgBytes == null) {
      _showSnackbar(context, '❌ Please provide a foreground image');
      return;
    }

    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      _showSnackbar(context, '❌ Storage permission denied. Please enable it from Settings.');
      return;
    }

    isLoading = true;
    blendedBytes = null;
    outBytes = null;
    notifyListeners();

    try {
      Uint8List output;

      if (bgBytes != null) {
        final fgClean = await ImageProcessor.removeBackground(fgBytes!, context);
        if (fgClean == null) throw Exception('Background removal failed');

        output = await ImageProcessor.addSubjectAsWatermark(fgClean, bgBytes!);

        if (userText.trim().isNotEmpty) {
          output = await ImageProcessor.renderTextOverImage(output, userText);
        }
      } else if (userText.trim().isNotEmpty) {
        output = await ImageProcessor.renderTextOverImage(fgBytes!, userText);
      } else {
        throw Exception('Please provide either a background image or input text');
      }

      if (theme == 'Barbie' || selectedTheme == UserTheme.barbie) {
        output = await ImageProcessor.addWatermark(output, '💖 Barbie World');
      } else if (theme == 'Traveller' || selectedTheme == UserTheme.traveller) {
        output = await ImageProcessor.addWatermark(output, '✈️ Travel Diaries');
      }

      if (isLocationSet && latitude != null && longitude != null) {
        final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
        output = ImageProcessor.embedMapUrlInPngMetadata(output, mapUrl);
      }

      outBytes = output;

      final fms = FlutterMediaStore();
      await fms.saveFile(
        fileData: outBytes!,
        mimeType: 'image/png',
        fileName: 'morphed_image_${DateTime.now().millisecondsSinceEpoch}.png',
        rootFolderName: 'Pictures',
        folderName: 'ImageMorpher',
        onSuccess: (_, __) => _showSnackbar(context, '✅ Image saved to gallery'),
        onError: (e) => _showSnackbar(context, '❌ Error saving image: $e'),
      );
    } catch (e) {
      _showSnackbar(context, '❌ Morphing failed: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}