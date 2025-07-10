import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
import '../widgets/themed_buttons.dart';
import '../widgets/upload_foreground.dart';
import '../widgets/upload_background.dart';
import '../widgets/input_text.dart';
import '../widgets/social_share_buttons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = HomeController();
  String selectedTheme = 'Barbie'; // Only Barbie and Traveller supported

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() => setState(() {});
  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canAddWatermark = controller.fgBytes != null &&
        (controller.bgBytes != null || controller.userText.trim().isNotEmpty);

    // Update controller theme
    controller.setTheme(selectedTheme == 'Barbie'
        ? UserTheme.barbie
        : UserTheme.traveller);

    // Theme-based watermark button
    final Widget watermarkButton = selectedTheme == 'Barbie'
        ? BarbieButton(
            onPressed: _handleWatermark,
            isEnabled: canAddWatermark,
            isLoading: controller.isLoading,
          )
        : TravelButton(
            onPressed: _handleWatermark,
            isEnabled: canAddWatermark,
            isLoading: controller.isLoading,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('PicMe'),
        backgroundColor: selectedTheme == 'Barbie' ? Colors.pink : Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset All',
            onPressed: controller.resetAll,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Theme toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Barbie'),
                  selected: selectedTheme == 'Barbie',
                  selectedColor: Colors.pinkAccent,
                  onSelected: (_) => setState(() => selectedTheme = 'Barbie'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Traveller'),
                  selected: selectedTheme == 'Traveller',
                  selectedColor: Colors.lightBlue,
                  onSelected: (_) => setState(() => selectedTheme = 'Traveller'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            UploadForeground(
              onImageSelected: (bytes) {
                controller.setForeground(bytes);
                if (controller.livePreview &&
                    controller.fgBytes != null &&
                    controller.bgBytes != null) {
                  controller.createImage(context);
                }
              },
              image: controller.fgBytes,
            ),
            const SizedBox(height: 10),

            UploadBackground(
              onImageSelected: (bytes) {
                controller.setBackground(bytes);
                if (controller.livePreview &&
                    controller.fgBytes != null &&
                    controller.bgBytes != null) {
                  controller.createImage(context);
                }
              },
              image: controller.bgBytes,
            ),
            const SizedBox(height: 10),

            InputText(
              onTextChanged: (text) {
                controller.setText(text);
                if (controller.livePreview &&
                    controller.fgBytes != null &&
                    controller.bgBytes != null) {
                  controller.createImage(context);
                }
              },
            ),
            Row(
              children: [
                Checkbox(
                  value: controller.livePreview,
                  onChanged: (v) => controller.toggleLivePreview(v ?? false),
                ),
                const Text('Live Preview'),
              ],
            ),
            const SizedBox(height: 20),

            // Dynamic button
            watermarkButton,

            if (controller.isLoading) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              const Text('Processing...'),
            ],

            if (controller.outBytes != null) ...[
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Image.memory(controller.outBytes!),
                  if (controller.isLocationSet)
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.blue),
                      tooltip: 'Open in Google Maps',
                      onPressed: () => controller.openInGoogleMaps(context),
                    ),
                ],
              ),
              if (controller.isLocationSet &&
                  controller.latitude != null &&
                  controller.longitude != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '📍 Lat: ${controller.latitude!.toStringAsFixed(6)}, '
                    'Lng: ${controller.longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              const SizedBox(height: 10),
              const Text('✅ Done – saved to gallery'),
              const SizedBox(height: 20),

              SocialShareButtons(
                imageBytes: controller.outBytes!,
                caption: 'Check this #viral PicMe image!',
              ),
            ],

            const SizedBox(height: 30),

            // Map icon from assets/images/MapMe.png
            GestureDetector(
              onTap: () => controller.getLocation(context),
              child: Image.asset(
                'assets/images/MapMe.png',
                height: 60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWatermark() async {
    if (controller.fgBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Please select a foreground image first.')),
      );
      return;
    }
    await controller.createImage(context);
  }
}
