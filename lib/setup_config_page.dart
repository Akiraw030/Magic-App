import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'image_crop.dart';
import 'card_reveal_page.dart';

class BlockData {
  double x;
  double y;
  double width;
  double height;
  String type;
  int imageIndex;

  BlockData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
    required this.imageIndex,
  });

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'type': type,
    'imageIndex': imageIndex,
  };

  static BlockData fromJson(Map<String, dynamic> json) => BlockData(
    x: json['x'],
    y: json['y'],
    width: json['width'],
    height: json['height'],
    type: json['type'],
    imageIndex: json['imageIndex'],
  );

  Rect get rect => Rect.fromLTWH(x, y, width, height);
}

// ... import statements 如你原本的代碼
// 已省略 import 部分

class SetupConfigPage extends StatefulWidget {
  @override
  State<SetupConfigPage> createState() => _SetupConfigPageState();
}

class _SetupConfigPageState extends State<SetupConfigPage> {
  String? image1Path;
  String? image2Path;
  int selectedImageIndex = 0;
  List<BlockData> blocks = [];
  double defaultSize = 80;
  double? _selectedHeight;

  @override
  void initState() {
    super.initState();
    _loadImagesAndBlocks();
  }

  Future<void> _loadImagesAndBlocks() async {
    final prefs = await SharedPreferences.getInstance();
    image1Path = prefs.getString('image1_path');
    image2Path = prefs.getString('image2_path');

    final stored = prefs.getString('tap_blocks');
    if (stored != null) {
      final List<dynamic> decoded = jsonDecode(stored);
      blocks = decoded.map((e) => BlockData.fromJson(e)).toList();
    } else {
      blocks = _generateDefaultBlocks();
    }

    setState(() {});
  }

  List<BlockData> _generateDefaultBlocks() {
    List<BlockData> defaultBlocks = [];
    double bottomY = 600;

    defaultBlocks.addAll([
      BlockData(x: 20, y: bottomY, width: defaultSize, height: defaultSize, type: 'suit_spade', imageIndex: 0),
      BlockData(x: 100, y: bottomY, width: defaultSize, height: defaultSize, type: 'suit_heart', imageIndex: 0),
      BlockData(x: 180, y: bottomY, width: defaultSize, height: defaultSize, type: 'suit_club', imageIndex: 0),
      BlockData(x: 260, y: bottomY, width: defaultSize, height: defaultSize, type: 'suit_diamond', imageIndex: 0),
    ]);

    double startX = 20;
    double startY = 100;
    double gap = 80;
    int number = 1;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 4; col++) {
        defaultBlocks.add(BlockData(
          x: startX + col * gap,
          y: startY + row * gap,
          width: defaultSize,
          height: defaultSize,
          type: 'rank_$number',
          imageIndex: 0,
        ));
        number++;
      }
    }

    defaultBlocks.add(BlockData(
      x: startX,
      y: startY + 3 * gap,
      width: defaultSize,
      height: defaultSize,
      type: 'rank_13',
      imageIndex: 0,
    ));

    defaultBlocks.add(BlockData(
      x: startX + gap,
      y: startY + 3 * gap,
      width: defaultSize,
      height: defaultSize,
      type: 'joker',
      imageIndex: 0,
    ));

    defaultBlocks.addAll([
      BlockData(x: 50, y: 300, width: defaultSize, height: defaultSize, type: 'open_setting', imageIndex: 1),
      BlockData(x: 200, y: 300, width: defaultSize, height: defaultSize, type: 'start_animation', imageIndex: 1),
    ]);

    return defaultBlocks;
  }

  Future<void> _saveConfig() async {
    for (int page = 0; page <= 1; page++) {
      final pageBlocks = blocks.where((b) => b.imageIndex == page).toList();
      for (int i = 0; i < pageBlocks.length; i++) {
        for (int j = i + 1; j < pageBlocks.length; j++) {
          if (pageBlocks[i].rect.overlaps(pageBlocks[j].rect)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('第 ${page + 1} 頁有重疊區塊')),
            );
            return;
          }
        }
      }
    }

    final hasPage0 = blocks.any((b) => b.imageIndex == 0);
    final hasPage1 = blocks.any((b) => b.imageIndex == 1);
    if (!hasPage0 || !hasPage1) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('設定不完整'),
          content: Text('請確認兩張截圖的互動區域都已設定'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('好的')),
          ],
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(blocks.map((b) => b.toJson()).toList());
    await prefs.setString('tap_blocks', jsonStr);

    Navigator.pushReplacementNamed(context, '/reveal');
  }

  void _onDrag(int index, DragUpdateDetails details) {
    setState(() {
      blocks[index].x += details.delta.dx;
      blocks[index].y += details.delta.dy;
    });
  }

  void _resizeBlock(int index, DragUpdateDetails details) {
    setState(() {
      blocks[index].width += details.delta.dx;
      blocks[index].height += details.delta.dy;
    });
  }

  Future<XFile?> _pickImage() async {
    final picker = ImagePicker();
    return await picker.pickImage(source: ImageSource.gallery);
  }

  @override
  Widget build(BuildContext context) {
    String? imagePath = selectedImageIndex == 0 ? image1Path : image2Path;
    if (imagePath == null) {
      return Scaffold(body: Center(child: Text("尚未選擇圖片")));
    }

    List<BlockData> visibleBlocks = blocks.where((b) => b.imageIndex == selectedImageIndex).toList();

    return Scaffold(
      extendBodyBehindAppBar: true, // 讓 body 延伸到 AppBar 背後
      backgroundColor: Colors.transparent, // Scaffold 背景透明
      appBar: AppBar(
        title: Text('設定點擊範圍'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
            ),
          ),
          // blocks 疊在圖片上
          ...visibleBlocks.asMap().entries.map((entry) {
            int index = blocks.indexOf(entry.value);
            BlockData b = entry.value;
            return Positioned(
              left: b.x,
              top: b.y,
              child: GestureDetector(
                onPanUpdate: (details) => _onDrag(index, details),
                child: Stack(
                  children: [
                    Container(
                      width: b.width,
                      height: b.height,
                      color: Colors.blue.withOpacity(0.3),
                      child: Center(
                        child: Text(
                          b.type,
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onPanUpdate: (d) => _resizeBlock(index, d),
                        child: Container(
                          width: 15,
                          height: 15,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          // Bottom 按鈕疊在畫面下方
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedImageIndex = selectedImageIndex == 0 ? 1 : 0;
                          });
                        },
                        child: Text("切換頁面"),
                      ),
                      ElevatedButton(
                        onPressed: _saveConfig,
                        child: Text("儲存"),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('tap_blocks');
                          setState(() {
                            blocks = _generateDefaultBlocks();
                          });
                        },
                        child: Text('回歸預設值'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final selectedHeight = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SetupCropPage()),
                          );

                          if (selectedHeight != null && selectedHeight is double) {
                            setState(() {
                              _selectedHeight = selectedHeight;
                            });

                            // ✅ 儲存到 SharedPreferences 以供 CardRevealPage 使用
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setDouble('bottom_overlay_height', selectedHeight);
                          }
                        },
                        child: Text('設定裁切高度'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final img1 = await _pickImage();
                          final img2 = await _pickImage();
                          if (img1 != null && img2 != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('image1_path', img1.path);
                            await prefs.setString('image2_path', img2.path);
                            setState(() {
                              image1Path = img1.path;
                              image2Path = img2.path;
                            });
                          }
                        },
                        child: Text('重新上傳截圖'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
