import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'setup_config_page.dart';

class ImageSetupPage extends StatefulWidget {
  @override
  _ImageSetupPageState createState() => _ImageSetupPageState();
}

class _ImageSetupPageState extends State<ImageSetupPage> {
  File? image1;
  File? image2;

  Future<void> pickImage(int index) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        if (index == 1) {
          image1 = File(picked.path);
        } else {
          image2 = File(picked.path);
        }
      });
    }
  }

  Future<void> saveAndProceed() async {
    if (image1 != null && image2 != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('image1_path', image1!.path);
      await prefs.setString('image2_path', image2!.path);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SetupConfigPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("選擇兩張背景截圖")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => pickImage(1),
            child: Text(image1 == null ? "選擇第一張截圖" : "已選擇：${image1!.path.split('/').last}"),
          ),
          ElevatedButton(
            onPressed: () => pickImage(2),
            child: Text(image2 == null ? "選擇第二張截圖" : "已選擇：${image2!.path.split('/').last}"),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: (image1 != null && image2 != null) ? saveAndProceed : null,
            child: Text("儲存並進入"),
          ),
        ],
      ),
    );
  }
}