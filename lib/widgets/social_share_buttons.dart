import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialShareButtons extends StatelessWidget {
  final Uint8List imageBytes;
  final String caption;

  const SocialShareButtons({
    super.key,
    required this.imageBytes,
    this.caption = '',
  });

  Future<String> _saveTempImage() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/shared_image.png');
    await file.writeAsBytes(imageBytes);
    return file.path;
  }

  Future<void> _launchUrlOrFallback(BuildContext context, Uri uri, String platform) async {
    final can = await canLaunchUrl(uri);
    if (can) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // fallback to sharing
      final path = await _saveTempImage();
      await Share.shareXFiles(
        [XFile(path)],
        text: '$caption #PicMe',
        subject: 'Shared via PicMe App ($platform)',
      );
    }
  }

  void _shareToTikTok(BuildContext context) async {
  final tiktokUri = Uri.parse('snssdk1128://'); // TikTok scheme
  await _launchUrlOrFallback(context, tiktokUri, 'TikTok');
  }

  void _shareToInstagram(BuildContext context) async {
    final instaUri = Uri.parse('instagram://camera');
    await _launchUrlOrFallback(context, instaUri, 'Instagram');
  }

  void _shareToFacebook(BuildContext context) async {
    final fbUri = Uri.parse('fb://facewebmodal/f?href=https://facebook.com');
    await _launchUrlOrFallback(context, fbUri, 'Facebook');
  }

  void _shareToWhatsApp(BuildContext context) async {
    final whatsappUri = Uri.parse('whatsapp://send');
    await _launchUrlOrFallback(context, whatsappUri, 'WhatsApp');
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      alignment: WrapAlignment.center,
      children: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.facebook, color: Colors.blue),
          tooltip: 'Open Facebook',
          onPressed: () => _shareToFacebook(context),
        ),
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.instagram, color: Colors.purple),
          tooltip: 'Open Instagram',
          onPressed: () => _shareToInstagram(context),
        ),
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.tiktok, color: Colors.black),
          tooltip: 'Open TikTok',
          onPressed: () => _shareToTikTok(context),
        ),
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
          tooltip: 'Open WhatsApp',
          onPressed: () => _shareToWhatsApp(context),
        ),
      ],
    );
  }
}