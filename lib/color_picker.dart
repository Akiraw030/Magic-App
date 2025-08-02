import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ColorPickerPage extends StatefulWidget {
  final Color initialColor;
  final String backgroundImagePath;

  const ColorPickerPage({
    super.key,
    required this.initialColor,
    required this.backgroundImagePath,
  });

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage> {
  late Color _pickedColor;
  ui.Image? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _pickedColor = widget.initialColor;
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await File(widget.backgroundImagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    setState(() {
      _backgroundImage = frame.image;
    });
  }

  Future<void> _pickColorFromPosition(Offset position, BoxConstraints constraints) async {
    if (_backgroundImage == null) return;

    final scaleX = _backgroundImage!.width / constraints.maxWidth;
    final scaleY = _backgroundImage!.height / constraints.maxHeight;
    final pixelX = (position.dx * scaleX).clamp(0, _backgroundImage!.width - 1).toInt();
    final pixelY = (position.dy * scaleY).clamp(0, _backgroundImage!.height - 1).toInt();

    final byteData = await _backgroundImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = (pixelY * _backgroundImage!.width + pixelX) * 4;

    final r = byteData!.getUint8(offset);
    final g = byteData.getUint8(offset + 1);
    final b = byteData.getUint8(offset + 2);

    setState(() {
      _pickedColor = Color.fromRGBO(r, g, b, _pickedColor.opacity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _backgroundImage == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: (details) => _pickColorFromPosition(details.localPosition, constraints),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(widget.backgroundImagePath),
                  fit: BoxFit.cover,
                ),

                Positioned(
                  top: 40,
                  right: 20,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _pickedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 80,
                  left: 20,
                  right: 20,
                  child: Slider(
                    value: _pickedColor.opacity,
                    min: 0,
                    max: 1,
                    onChanged: (value) {
                      setState(() {
                        _pickedColor = _pickedColor.withOpacity(value);
                      });
                    },
                  ),
                ),

                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _pickedColor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.6),
                    ),
                    child: const Text("確定"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
