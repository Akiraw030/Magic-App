import 'dart:ui';

class InteractionArea {
  final String id;
  final Rect area;
  final String type; // e.g. 'suit', 'rank', 'joker', 'reveal', 'settings'
  final int pageIndex; // 0 for first screenshot, 1 for second screenshot

  InteractionArea({
    required this.id,
    required this.area,
    required this.type,
    required this.pageIndex,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'left': area.left,
    'top': area.top,
    'width': area.width,
    'height': area.height,
    'type': type,
    'pageIndex': pageIndex,
  };

  factory InteractionArea.fromJson(Map<String, dynamic> json) {
    return InteractionArea(
      id: json['id'],
      area: Rect.fromLTWH(
        (json['left'] as num).toDouble(),
        (json['top'] as num).toDouble(),
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      ),
      type: json['type'],
      pageIndex: json['pageIndex'] ?? 0,
    );
  }
}

// 使用說明：
// pageIndex = 0 代表第一張截圖（花色與點數）
// pageIndex = 1 代表第二張截圖（設定與信封）
