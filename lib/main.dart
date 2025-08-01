import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'image_setup_page.dart';
import 'card_reveal_page.dart';
import 'setup_config_page.dart';
import 'dart:convert';
import 'package:flutter/services.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // <-- 加這行
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  Future<String> getStartPage() async {
    final prefs = await SharedPreferences.getInstance();

    final hasImages =
        prefs.containsKey('image1_path') && prefs.containsKey('image2_path');
    if (!hasImages) return 'imageSetup';

    final hasValidBlocks = await hasValidTapBlocks();
    if (!hasValidBlocks) return 'setupConfig';

    return 'reveal';
  }

  Future<bool> hasValidTapBlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final tapBlocksString = prefs.getString('tap_blocks');
    if (tapBlocksString == null) return false;

    try {
      // 這裡用 jsonDecode 將字串解析成 List<dynamic>
      final List<dynamic> decoded = jsonDecode(tapBlocksString);

      // 將 List<dynamic> 中每個元素轉成 Map<String, dynamic>
      final List<Map<String, dynamic>> blocks = decoded
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // 判斷 imageIndex 是否包含 0 和 1
      final hasFirstImageBlock = blocks.any((b) => b['imageIndex'] == 0);
      final hasSecondImageBlock = blocks.any((b) => b['imageIndex'] == 1);

      return hasFirstImageBlock && hasSecondImageBlock;
    } catch (e) {
      debugPrint("Error parsing tap blocks: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magic Card App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      routes: {
        '/setup': (context) => ImageSetupPage(),
        '/reveal': (context) => CardRevealPage(),
        '/setupConfig': (context) => SetupConfigPage(),
      },
      home: FutureBuilder<String>(
        future: getStartPage(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          switch (snapshot.data) {
            case 'imageSetup':
              return ImageSetupPage();
            case 'setupConfig':
              return SetupConfigPage();
            case 'reveal':
            default:
              return CardRevealPage();
          }
        },
      ),
    );
  }
}
