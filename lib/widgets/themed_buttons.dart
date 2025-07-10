import 'package:flutter/material.dart';

class ImageThemedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String assetPath;
  final bool isLoading;
  final bool isEnabled;
  final double width;
  final double height;

  const ImageThemedButton({
    super.key,
    required this.onPressed,
    required this.assetPath,
    this.isLoading = false,
    this.isEnabled = true,
    this.width = 200,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled && !isLoading ? onPressed : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              assetPath,
              width: width,
              height: height,
              fit: BoxFit.contain,
            ),
            if (isLoading)
              const Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BarbieButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;

  const BarbieButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ImageThemedButton(
      onPressed: onPressed,
      assetPath: 'assets/images/BarbieBuild.png',
      isLoading: isLoading,
      isEnabled: isEnabled,
    );
  }
}

class TravelButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;

  const TravelButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ImageThemedButton(
      onPressed: onPressed,
      assetPath: 'assets/images/TravelBuild.png',
      isLoading: isLoading,
      isEnabled: isEnabled,
    );
  }
}