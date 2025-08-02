import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupCropPage extends StatelessWidget {
  final String title;
  final String storageKey;
  final String backgroundImageKey;

  const SetupCropPage({
    super.key,
    required this.title,
    required this.storageKey,
    required this.backgroundImageKey,
  });

  Future<void> _saveFixedHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(storageKey, height);
  }

  Future<String?> _getBackgroundImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(backgroundImageKey);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getBackgroundImagePath(),
      builder: (context, snapshot) {
        final imagePath = snapshot.data;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          body: imagePath == null
              ? const Center(child: Text('尚未設定背景圖片'))
              : LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (TapDownDetails details) {
                  final y = details.localPosition.dy;
                  final screenHeight = constraints.maxHeight;
                  final height = screenHeight - y;

                  _saveFixedHeight(height);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已儲存高度: ${height.toInt()}'), duration: Duration(seconds: 1),),
                  );

                  Navigator.pop(context, height);
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
