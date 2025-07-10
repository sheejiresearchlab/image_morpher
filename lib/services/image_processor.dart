import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:local_rembg/local_rembg.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ImageProcessor {
  /// Remove background using local_rembg plugin
  static Future<Uint8List?> removeBackground(Uint8List bytes, BuildContext context) async {
    try {
      final result = await LocalRembg.removeBackground(
        imageUint8List: bytes,
        cropTheImage: false,
      );
      return result.imageBytes != null ? Uint8List.fromList(result.imageBytes!) : null;
    } catch (e) {
      debugPrint('❌ Background removal failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Background removal failed: $e')),
      );
      return null;
    }
  }

  /// Blend foreground and background images with resized foreground centered
  static Future<Uint8List> blendFgBg(Uint8List fg, Uint8List bg) async {
    return await compute(_blend, {'fg': fg, 'bg': bg});
  }

  static Uint8List _blend(Map<String, Uint8List> params) {
    final fg = img.decodeImage(params['fg']!)!;
    final bg = img.decodeImage(params['bg']!)!;

    final targetWidth = (bg.width * 0.5).toInt();
    final scaleFactor = targetWidth / fg.width;
    final targetHeight = (fg.height * scaleFactor).toInt();

    final fgResized = img.copyResize(fg, width: targetWidth, height: targetHeight);
    final startX = (bg.width - fgResized.width) ~/ 2;
    final startY = (bg.height - fgResized.height) ~/ 2;

    for (int y = 0; y < fgResized.height; y++) {
      for (int x = 0; x < fgResized.width; x++) {
        final pixel = fgResized.getPixel(x, y);
        final alpha = pixel.a / 255.0;
        if (alpha > 0) {
          final bgPixel = bg.getPixelSafe(startX + x, startY + y);
          final r = (pixel.r * alpha + bgPixel.r * (1 - alpha)).toInt();
          final g = (pixel.g * alpha + bgPixel.g * (1 - alpha)).toInt();
          final b = (pixel.b * alpha + bgPixel.b * (1 - alpha)).toInt();
          bg.setPixelRgba(startX + x, startY + y, r, g, b, 255);
        }
      }
    }

    bg.convert(numChannels: 4);
    return Uint8List.fromList(img.encodePng(bg));
  }

  /// Render user text on top of the image, centered horizontally near top with shadow
  static Future<Uint8List> renderTextOverImage(Uint8List imageBytes, String text) async {
    if (text.trim().isEmpty) return imageBytes;

    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    canvas.drawImage(uiImage, Offset.zero, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 150,
          color: Colors.white,
          shadows: [Shadow(offset: Offset(2, 2), blurRadius: 3, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    const padding = 20.0;
    final offset = Offset((uiImage.width - textPainter.width) / 2, padding);
    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final imgWithText = await picture.toImage(uiImage.width, uiImage.height);
    final byteData = await imgWithText.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Add watermark text with opacity 0.9 centered on image
  /// This method respects themes by passing specific watermarkText from controller
 static Future<Uint8List> addWatermark(
    Uint8List imageBytes,
    String watermarkText, {
    double fontSize = 40,
    double opacity = 0.9,
  }) async {
    if (watermarkText.trim().isEmpty) return imageBytes;

    // Clamp opacity for safety
    final double safeOpacity = opacity.clamp(0.0, 1.0);
    final int alpha = (255 * safeOpacity).clamp(0, 255).toInt();

    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    canvas.drawImage(uiImage, Offset.zero, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: watermarkText,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(alpha, 255, 255, 255), // white with alpha
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 2,
              color: Color.fromARGB(alpha, 0, 0, 0), // black with alpha
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Center the watermark text
    final offset = Offset(
      (uiImage.width - textPainter.width) / 2,
      (uiImage.height - textPainter.height) / 2,
    );

    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(uiImage.width, uiImage.height);
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('❌ Failed to generate image byte data');
    }

    return byteData.buffer.asUint8List();
  }

  /// Add the subject image as a semi-transparent watermark over the background image
  static Future<Uint8List> addSubjectAsWatermark(Uint8List fgBytes, Uint8List bgBytes) async {
    final fg = img.decodeImage(fgBytes)!;
    final bg = img.decodeImage(bgBytes)!;

    // Resize foreground to 40% of background width for better center visibility
    final targetWidth = (bg.width * 0.4).toInt();
    final scale = targetWidth / fg.width;
    final targetHeight = (fg.height * scale).toInt();
    final fgResized = img.copyResize(fg, width: targetWidth, height: targetHeight);

    // Center coordinates
    final startX = (bg.width - fgResized.width) ~/ 2;
    final startY = (bg.height - fgResized.height) ~/ 2;

    const opacity = 0.9;

    for (int y = 0; y < fgResized.height; y++) {
      for (int x = 0; x < fgResized.width; x++) {
        final fgPixel = fgResized.getPixel(x, y);
        final alpha = fgPixel.a / 255.0;

        if (alpha > 0.01) {
          final bgPixel = bg.getPixelSafe(startX + x, startY + y);
          final blendAlpha = alpha * opacity;

          final r = (fgPixel.r * blendAlpha + bgPixel.r * (1 - blendAlpha)).toInt();
          final g = (fgPixel.g * blendAlpha + bgPixel.g * (1 - blendAlpha)).toInt();
          final b = (fgPixel.b * blendAlpha + bgPixel.b * (1 - blendAlpha)).toInt();

          bg.setPixelRgba(startX + x, startY + y, r, g, b, 255);
        }
      }
    }

    return Uint8List.fromList(img.encodePng(bg));
  }

  /// Embed Google Maps URL in PNG metadata
  static Uint8List embedMapUrlInPngMetadata(Uint8List pngBytes, String mapUrl) {
    final image = img.decodeImage(pngBytes);
    if (image == null) {
      throw Exception('Failed to decode PNG for metadata embedding');
    }

    final encodedImage = img.encodePng(image);
    final key = 'LocationLink';
    final textData = utf8.encode('$key\u0000$mapUrl');
    final chunkType = Uint8List.fromList([0x74, 0x45, 0x58, 0x74]); // 'tEXt'
    final chunk = _createPngChunk(chunkType, Uint8List.fromList(textData));
    return _insertChunkAfterIHDR(Uint8List.fromList(encodedImage), chunk);
  }

  static Uint8List _insertChunkAfterIHDR(Uint8List png, Uint8List chunk) {
    const pngSignatureLength = 8;
    const ihdrChunkTotalLength = 25;
    final before = png.sublist(0, pngSignatureLength + ihdrChunkTotalLength);
    final after = png.sublist(pngSignatureLength + ihdrChunkTotalLength);
    return Uint8List.fromList([...before, ...chunk, ...after]);
  }

  static Uint8List _createPngChunk(List<int> type, Uint8List data) {
    final length = ByteData(4)..setUint32(0, data.length);
    final crcData = Uint8List.fromList(type + data);
    final crc = _crc32(crcData);

    final builder = BytesBuilder()
      ..add(length.buffer.asUint8List())
      ..add(type)
      ..add(data)
      ..add(crc.buffer.asUint8List());

    return builder.toBytes();
  }

  static ByteData _crc32(Uint8List data) {
    const table = _crc32Table;
    int crc = 0xffffffff;
    for (final b in data) {
      crc = table[(crc ^ b) & 0xff] ^ (crc >> 8);
    }
    crc = crc ^ 0xffffffff;
    final bytes = ByteData(4)..setUint32(0, crc);
    return bytes;
  }

  /// Overlay QR code with Google Maps URL in bottom-right corner with padding
  static Future<Uint8List> overlayQrCode(Uint8List imageBytes, double latitude, double longitude) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    canvas.drawImage(uiImage, Offset.zero, paint);

    final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    final qrCode = QrCode.fromData(
      data: mapUrl,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );

    final qrPainter = QrPainter.withQr(
      qr: qrCode,
      dataModuleStyle: const QrDataModuleStyle(
        color: Colors.black,
        dataModuleShape: QrDataModuleShape.square,
      ),
      eyeStyle: const QrEyeStyle(
        color: Colors.black,
        eyeShape: QrEyeShape.square,
      ),
    );

    const qrSize = 200.0;
    final qrImage = await qrPainter.toImage(qrSize);
    final byteData = await qrImage.toByteData(format: ui.ImageByteFormat.png);
    final qrBytes = byteData!.buffer.asUint8List();

    final qrCodec = await ui.instantiateImageCodec(qrBytes);
    final qrFrame = await qrCodec.getNextFrame();
    final qrUiImage = qrFrame.image;

    // Position bottom-right with padding
    const padding = 20.0;
    final dx = uiImage.width - qrUiImage.width - padding;
    final dy = uiImage.height - qrUiImage.height - padding;
    canvas.drawImage(qrUiImage, Offset(dx, dy), Paint());

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(uiImage.width, uiImage.height);
    final finalByteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return finalByteData!.buffer.asUint8List();
  }

  static const List<int> _crc32Table = [
    0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F,
    0xE963A535, 0x9E6495A3, 0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988,
    0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91, 0x1DB71064, 0x6AB020F2,
    0xF3B97148, 0x84BE41DE, 0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
    0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC, 0x14015C4F, 0x63066CD9,
    0xFA0F3D63, 0x8D080DF5, 0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172,
    0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B, 0x35B5A8FA, 0x42B2986C,
    0xDBBBC9D6, 0xACBCF940, 0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
    0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116, 0x21B4F4B5, 0x56B3C423,
    0xCFBA9599, 0xB8BDA50F, 0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924,
    0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D, 0x76DC4190, 0x01DB7106,
    0x98D220BC, 0xEFD5102A, 0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
    0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818, 0x7F6A0DBB, 0x086D3D2D,
    0x91646C97, 0xE6635C01, 0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E,
    0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457, 0x65B0D9C6, 0x12B7E950,
    0x8BBEB8EA, 0xFCB9887C, 0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
    0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2, 0x4ADFA541, 0x3DD895D7,
    0xA4D1C46D, 0xD3D6F4FB, 0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0,
    0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9, 0x5005713C, 0x270241AA,
    0xBE0B1010, 0xC90C2086, 0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
    0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4, 0x59B33D17, 0x2EB40D81,
    0xB7BD5C3B, 0xC0BA6CAD, 0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A,
    0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683, 0xE3630B12, 0x94643B84,
    0x0D6D6A3E, 0x7A6A5AA8, 0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
    0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE, 0xF762575D, 0x806567CB,
    0x196C3671, 0x6E6B06E7, 0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC,
    0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5, 0xD6D6A3E8, 0xA1D1937E,
    0x38D8C2C4, 0x4FDFF252, 0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
    0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60, 0xDF60EFC3, 0xA867DF55,
    0x316E8EEF, 0x4669BE79, 0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236,
    0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F, 0xC5BA3BBE, 0xB2BD0B28,
    0x2BB45A92, 0x5CB36A04, 0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
    0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A, 0x9C0906A9, 0xEB0E363F,
    0x72076785, 0x05005713, 0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38,
    0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21, 0x86D3D2D4, 0xF1D4E242,
    0x68DDB3F8, 0x1FDA836E, 0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
    0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C, 0x8F659EFF, 0xF862AE69,
    0x616BFFD3, 0x166CCF45, 0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2,
    0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB, 0xAED16A4A, 0xD9D65ADC,
    0x40DF0B66, 0x37D83BF0, 0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
    0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6, 0xBAD03605, 0xCDD70693,
    0x54DE5729, 0x23D967BF, 0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94,
    0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D
  ];
}