// lib/setup_crop_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupCropPage extends StatelessWidget {
  const SetupCropPage({super.key});

  Future<void> _saveFixedHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bottom_overlay_height', height); // 統一 key
  }

  Future<String?> _getBackgroundImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('image2_path'); // 建議使用第二頁背景
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
          appBar: AppBar(
            title: const Text('設定底部裁切高度'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
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
                    SnackBar(content: Text('已儲存高度: ${height.toInt()}')),
                  );

                  // ✅ 返回 SetupConfigPage
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
                    const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          '點擊畫面底部想要保留的地方',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
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
