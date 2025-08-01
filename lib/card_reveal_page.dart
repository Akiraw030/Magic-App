import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'image_crop.dart';


class BlockData {
  double x, y, width, height;
  String type;
  int imageIndex; // 頁碼從0開始

  BlockData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
    required this.imageIndex,
  });

  factory BlockData.fromJson(Map<String, dynamic> json) {
    return BlockData(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      type: json['type'],
      imageIndex: json['imageIndex'],
    );
  }

  Rect get rect => Rect.fromLTWH(x, y, width, height);
}

class CardRevealPage extends StatefulWidget {
  final double? overrideHeight; // ← 新增參數：來自外部的高度（可為 null）

  const CardRevealPage({Key? key, this.overrideHeight}) : super(key: key);

  @override
  _CardRevealPageState createState() => _CardRevealPageState();
}


class _CardRevealPageState extends State<CardRevealPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _revealed = false;
  bool hasTriggeredReveal = false;

  bool envelopeOpened = false;

  AccelerometerEvent? _lastEvent;

  String? _image1Path;
  String? _image2Path;
  List<BlockData> _blocks = [];
  late PageController _pageController;

  String? _selectedSuit;
  String? _selectedRank;

  int currentPage = 0;

  double? _bottomOverlayHeight;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadConfig();
    _initAnimation();
    _initShakeDetection();
  }

  void _initAnimation() {
    _controller = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset(0, -0.4),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  void _initShakeDetection() {
    accelerometerEvents.listen((event) {
      if (_revealed) return;
      double shakeThreshold = 15.0;

      if (_lastEvent != null) {
        double dx = (event.x - _lastEvent!.x).abs();
        double dy = (event.y - _lastEvent!.y).abs();
        double dz = (event.z - _lastEvent!.z).abs();
        double shake = sqrt(dx * dx + dy * dy + dz * dz);

        if (shake > shakeThreshold && envelopeOpened) {
          _controller.forward();
          setState(() {
            _revealed = true;
            hasTriggeredReveal = true;
          });
        }
      }
      _lastEvent = event;
    });
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('tap_blocks') ?? '[]';
    final List<dynamic> list = jsonDecode(jsonStr);

    setState(() {
      _image1Path = prefs.getString('image1_path');
      _image2Path = prefs.getString('image2_path');
      _blocks = list.map((e) => BlockData.fromJson(e)).toList();

      // 這邊：使用 widget.overrideHeight 優先，否則從 prefs 讀取 fallback 值
      _bottomOverlayHeight = widget.overrideHeight ?? prefs.getDouble('bottom_overlay_height') ?? 150.0;
    });
  }


  void _handleTap(TapDownDetails details, int pageIndex) {
    final Offset pos = details.localPosition;
    final currentPageBlocks = _blocks.where((b) => b.imageIndex == pageIndex).toList();

    for (var block in currentPageBlocks) {
      if (block.rect.contains(pos)) {
        print('page $pageIndex 點擊到 ${block.type}');

        if (pageIndex == 0) {
          if (block.type.startsWith("rank_")) {
            _selectedRank = block.type.replaceFirst("rank_", "");
          } else if (block.type.startsWith("suit_")) {
            _selectedSuit = block.type.replaceFirst("suit_", "");
          } else if (block.type == "joker") {
            _selectedRank = "joker";
            _selectedSuit = null;
          }
        } else if (pageIndex == 1) {
          if (block.type == 'start_animation') {
            setState(() {
              envelopeOpened = true;
              _revealed = false;
              hasTriggeredReveal = false;
              _controller.reset();
            });
          } else if (block.type == 'open_setting') {
            Navigator.pushReplacementNamed(context, '/setupConfig');
          }
        }
        return;
      }
    }
    print('page $pageIndex 沒點到任何範圍');
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPage1() {
    if (_image1Path == null) return Center(child: Text("沒有第一張圖"));

    return GestureDetector(
      onTapDown: (details) => _handleTap(details, 0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(_image1Path!), fit: BoxFit.cover),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    if (_image2Path == null) return Center(child: Text("沒有第二張圖"));

    String cardAsset = "assets/cards/back.png";
    if (_selectedRank == 'joker') {
      cardAsset = "assets/cards/joker.png";
    } else if (_selectedSuit != null && _selectedRank != null) {
      cardAsset = "assets/cards/${_selectedSuit!}_${_selectedRank!}.png";
    }

    return GestureDetector(
      onTapDown: (details) => _handleTap(details, 1),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(_image2Path!), fit: BoxFit.cover),
          if (envelopeOpened)
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, 70),
                    child: Image.asset('assets/envelope/envelope_bottom.png', width: 200),
                  ),
                  // 只要信封開啟，先顯示信封上下，卡牌在動畫控制器觸發時才顯示
                  if (_controller.status != AnimationStatus.dismissed)
                    SlideTransition(
                      position: _slideAnimation,
                      child: Transform.translate(
                        offset: Offset(0, -10),
                        child: Image.asset(cardAsset, width: 230),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(0, 90),
                    child: Image.asset('assets/envelope/envelope_top.png', width: 200),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // PageView takes everything except the bottom 400px
          Positioned.fill(
            bottom: 0, // ⬅ Reserve 400px at bottom for fixed widget
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  currentPage = index;
                });
              },
              children: [
                _buildPage1(),
                _buildPage2(),
              ],
            ),
          ),

          // Fixed bottom 400px part
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _bottomOverlayHeight ?? 150,
            child: IgnorePointer(
              ignoring: true, // Let touches pass through if needed
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // You can make this semi-transparent, blurred, or fully transparent
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),

                  // If you want to show part of the image here too
                  if (currentPage == 0 && _image1Path != null)
                    Image.file(
                      File(_image1Path!),
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                    ),
                  if (currentPage == 1 && _image2Path != null)
                    Image.file(
                      File(_image2Path!),
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                    ),

                  // You can overlay card/envelope visuals here too if needed
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
