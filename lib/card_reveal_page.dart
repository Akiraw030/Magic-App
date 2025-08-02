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
  final double? overrideHeight;
  final double? overrideTopHeight;

  const CardRevealPage({
    Key? key,
    this.overrideHeight,
    this.overrideTopHeight,
  }) : super(key: key);

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
  double? _topOverlayHeight;

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

      _bottomOverlayHeight = widget.overrideHeight ?? prefs.getDouble('bottom_overlay_height') ?? 150.0;
      _topOverlayHeight = widget.overrideTopHeight ?? prefs.getDouble('top_overlay_height') ?? 0.0;
    });
  }

  Future<Color> _loadMaskColor() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.getInt('mask_color_r') ?? 0;
    final g = prefs.getInt('mask_color_g') ?? 0;
    final b = prefs.getInt('mask_color_b') ?? 0;
    final a = prefs.getInt('mask_color_a') ?? 150;
    return Color.fromARGB(a, r, g, b);
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
        ],
      ),
    );
  }

  Widget _buildCardRevealAnimation() {
    if (!envelopeOpened || _selectedRank == null) return SizedBox.shrink();

    String cardAsset = "assets/cards/back.png";
    if (_selectedRank == 'joker') {
      cardAsset = "assets/cards/joker.png";
    } else if (_selectedSuit != null && _selectedRank != null) {
      cardAsset = "assets/cards/${_selectedSuit!}_${_selectedRank!}.png";
    }

    return IgnorePointer( // 確保動畫不擋點擊
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, 70),
              child: Image.asset('assets/envelope/envelope_bottom.png', width: 200),
            ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 0,
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

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _bottomOverlayHeight ?? 150,
            child: IgnorePointer(
              ignoring: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
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
                ],
              ),
            ),
          ),
          FutureBuilder<Color>(
            future: _loadMaskColor(),
            builder: (context, snapshot) {
              final color = snapshot.data ?? Colors.black.withOpacity(0.6);

              return LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      if (_topOverlayHeight != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: constraints.maxHeight - _topOverlayHeight!,
                          child: IgnorePointer(
                            child: Container(
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          _buildCardRevealAnimation(),
        ],
      ),
    );
  }
}
