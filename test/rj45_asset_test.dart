import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/rj45_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every RJ45 asset exists and decodes at usable resolution', () async {
    expect(Rj45Art.paths.length, 20);
    expect(Rj45Art.paths.toSet().length, 20);
    for (final path in Rj45Art.paths) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThanOrEqualTo(512), reason: path);
      expect(frame.image.height, greaterThanOrEqualTo(512), reason: path);
      frame.image.dispose();
      codec.dispose();
    }
  });
}
