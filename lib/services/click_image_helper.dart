import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

class ClickImageHelper {
  /// Embeds a simple blue map icon at bottom-right and stores clickable
  /// location metadata inside PNG tEXt chunk.
  static Future<Uint8List> embedLocationInImage(Uint8List originalBytes, double latitude, double longitude) async {
    final image = img.decodeImage(originalBytes)!;

    // Draw a simple blue map icon at bottom-right corner
    _drawMapIcon(image);

    // Prepare metadata string for location link
    final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    // Encode with PNG text chunk metadata
    final pngBytes = _encodePngWithTextChunk(image, 'LocationLink', mapUrl);

    return pngBytes;
  }

  /// Draw a simple blue map icon as a filled circle with a small white center
  static void _drawMapIcon(img.Image image) {
    const iconRadius = 24;
    final centerX = image.width - iconRadius - 10;
    final centerY = image.height - iconRadius - 10;

    // Blue circle
    img.drawCircle(image, centerX, centerY, iconRadius, img.getColor(30, 144, 255));
    // Smaller white circle inside
    img.drawCircle(image, centerX, centerY, iconRadius ~/ 2, img.getColor(255, 255, 255));
  }

  /// Encode PNG with text chunk metadata (tEXt chunk)
  static Uint8List _encodePngWithTextChunk(img.Image image, String keyword, String text) {
    final encoder = img.PngEncoder();

    // The image package doesn't have a direct addText method, but
    // you can pass a Map<String, String> for textual metadata
    final pngBytes = encoder.encodePng(image, text: {keyword: text});
    return Uint8List.fromList(pngBytes);
  }

  /// Launch the Google Maps URL for given coordinates
  static Future<void> openMap(double latitude, double longitude) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}