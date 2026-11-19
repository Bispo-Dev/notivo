import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../lib/brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final key = GlobalKey();
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: OverflowBox(
        minWidth: 144,
        maxWidth: 144,
        minHeight: 128,
        maxHeight: 128,
        child: RepaintBoundary(
          key: key,
          child: const ColoredBox(
            color: Colors.white,
            child: Center(
              child: NotivoAppIcon(
                size: 128,
                background: Color(0xff6d3bd2),
                markColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  WidgetsBinding.instance.scheduleFrame();
  await WidgetsBinding.instance.endOfFrame;
  final rendered =
      await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
          .toImage();
  final codec = await ui.instantiateImageCodec(
    File('app/assets/brand/app-icon-reference.png').readAsBytesSync(),
  );
  final target = (await codec.getNextFrame()).image;
  final actualBytes = (await rendered.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  final targetBytes = (await target.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  if (rendered.width != target.width || rendered.height != target.height)
    throw StateError('Icon dimensions differ');
  var total = 0;
  for (var i = 0; i < actualBytes.lengthInBytes; i++) {
    if (i % 4 != 3)
      total += (actualBytes.getUint8(i) - targetBytes.getUint8(i)).abs();
  }
  final error = total / (rendered.width * rendered.height * 3);
  File('.tooling/design-ref/icon-corrected.png').writeAsBytesSync(
    (await rendered.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
  print('Icon comparison: mean RGB difference $error / 255');
  if (error > 2) throw StateError('Icon differs from supplied reference');
  rendered.dispose();
  target.dispose();
  codec.dispose();
  exit(0);
}
