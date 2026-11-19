import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../lib/brand.dart';
import '../lib/design.dart';
import '../lib/reader_toolbar.dart';
import '../lib/color_picker.dart';
import '../lib/selection.dart';
import '../lib/sheets.dart';
import '../lib/strings.dart';

final errors = <String>[];
Future<void> frame() async {
  WidgetsBinding.instance.scheduleFrame();
  await WidgetsBinding.instance.endOfFrame;
}

Future<RenderRepaintBoundary> render(
  String name,
  Size size,
  bool dark,
  Widget Function(BuildContext) builder, {
  EdgeInsets insets = EdgeInsets.zero,
}) async {
  errors.clear();
  final key = GlobalKey();
  runApp(
    MaterialApp(
      key: ValueKey(name),
      locale: const Locale('pt'),
      supportedLocales: notivoSupportedLocales,
      localizationsDelegates: notivoLocalizationDelegates,
      themeAnimationDuration: Duration.zero,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        fontFamily: 'Inter',
      ),
      home: Builder(
        builder: (context) => OverflowBox(
          minWidth: size.width,
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
          child: MediaQuery(
            data: MediaQueryData(size: size, viewInsets: insets),
            child: RepaintBoundary(
              key: key,
              child: Material(
                color: NotivoColors(context).bg,
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  await frame();
  if (errors.isNotEmpty) throw StateError('$name: ${errors.join("\n")}');
  return key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
}

Future<void> capture(RenderRepaintBoundary boundary, String name) async {
  final image = await boundary.toImage();
  File('.tooling/design-ref/$name.png').writeAsBytesSync(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
  image.dispose();
}

Iterable<Element> descendants(Element root) sync* {
  yield root;
  final children = <Element>[];
  root.visitChildElements(children.add);
  for (final child in children) {
    yield* descendants(child);
  }
}

GestureDetector pickerGesture(String label) {
  final scope = descendants(WidgetsBinding.instance.rootElement!).firstWhere(
    (element) =>
        element.widget is Semantics &&
        (element.widget as Semantics).properties.label == label,
  );
  return descendants(scope)
      .map((element) => element.widget)
      .whereType<GestureDetector>()
      .firstWhere(
        (widget) =>
            widget.onPanDown != null || widget.onVerticalDragDown != null,
      );
}

Future<void> expectHex(String expected) async {
  await frame();
  final labels = descendants(WidgetsBinding.instance.rootElement!)
      .map((element) => element.widget)
      .whereType<Text>()
      .map((widget) => widget.data)
      .whereType<String>();
  if (!labels.contains(expected))
    throw StateError('Picker did not produce $expected');
  if (errors.isNotEmpty) throw StateError(errors.join('\n'));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final selection = ScoreSelection();
  final collectionA = selection, collectionB = selection;
  var changes = 0;
  selection.addListener(() => changes++);
  collectionA.toggle(10);
  collectionA.toggle(11);
  collectionB.toggle(12);
  if (selection.value.length != 3)
    throw StateError('Selection did not survive a collection change');
  final snapshot = selection.value;
  collectionB.toggle(10);
  if (selection.value.contains(10) ||
      selection.value.length != 2 ||
      snapshot.length != 3)
    throw StateError('Shared selection or immutable snapshot failed');
  selection.clear();
  if (selection.value.isNotEmpty || changes != 5)
    throw StateError('Clear did not update all collection listeners');
  selection.dispose();
  print(
    'PASS shared selection: multiple scores per collection, cross-collection toggle, clear and immutable snapshots.',
  );
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  final fonts = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold']) {
    fonts.addFont(
      File('app/assets/fonts/Inter-$weight.ttf')
          .readAsBytes()
          .then((b) => ByteData.sublistView(b)),
    );
  }
  await fonts.load();
  await (FontLoader('Source Serif 4')..addFont(
        File('app/assets/fonts/SourceSerif4[opsz,wght].ttf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)),
      ))
      .load();
  await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
        File(
          '.tooling/pub-cache/hosted/pub.dev/lucide_icons_flutter-4.0.3/assets/lucide.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      ))
      .load();
  for (final size in [
    const Size(320, 640),
    const Size(360, 640),
    const Size(411, 800),
    const Size(600, 960),
    const Size(834, 1194),
    const Size(914, 360),
  ]) {
    for (final dark in size.width == 834 ? [false, true] : [false]) {
      final cardKey = GlobalKey();
      final name = 'library-${size.width.toInt()}-${dark ? "dark" : "light"}';
      final boundary = await render(name, size, dark, (context) {
        final c = NotivoColors(context);
        return DesignViewport(
          child: LibraryLayout(
            brand: NotivoWordmark(
              fontSize: 40,
              color: c.dark ? Colors.white : c.tx,
              markColor: c.mark,
            ),
            onCreate: () {},
            onMenu: () {},
            cards: [
              CollectionCard(
                key: cardKey,
                name: 'Orquestra',
                count: 12,
                icon: LucideIcons.music,
                color: const Color(0xff6d3bd2),
                onOpen: () {},
              ),
              CollectionCard(
                name: 'Banda',
                count: 8,
                icon: LucideIcons.drum,
                color: c.banda,
                onOpen: () {},
              ),
              CollectionCard(
                name: 'Igreja',
                count: 15,
                icon: LucideIcons.church,
                color: const Color(0xffc9b6f5),
                iconColor: const Color(0xff2e1a6b),
                onOpen: () {},
              ),
              CollectionCard(
                name: 'Estudos',
                count: 6,
                icon: LucideIcons.bookOpen,
                color: const Color(0xff8a5ce8),
                onOpen: () {},
              ),
            ],
          ),
        );
      });
      final card = cardKey.currentContext!.findRenderObject()! as RenderBox;
      final origin = card.localToGlobal(Offset.zero, ancestor: boundary);
      final compact = size.width < 600 || size.height < 500;
      final gutter = compact ? (size.width < 360 ? 16.0 : 20.0) : 40.0;
      // Phones list the collections one per row; tablets use a two-column grid.
      final expectedWidth = compact
          ? size.width - 2 * gutter
          : (size.width - 2 * gutter - 16) / 2;
      if ((origin.dx - gutter).abs() > .01 ||
          (card.size.width - expectedWidth).abs() > .01 ||
          (card.size.height - (compact ? 72 : 120)).abs() > .01)
        throw StateError('$name geometry: $origin ${card.size}');
      await capture(boundary, name);
      if (size.width == 834)
        await capture(boundary, 'implemented-${dark ? "dark" : "light"}');
      print(
        'PASS $name: card ${card.size}, native proportions, no layout overflow.',
      );
    }
    final toolbarWidth = size.width - 24;
    const toolbarHeight = 64.0;
    final toolbarKey = GlobalKey();
    final toolbar = await render(
      'toolbar-${size.width.toInt()}',
      size,
      false,
      (context) => Stack(
        children: [
          Positioned(
            bottom: 12,
            left: (size.width - toolbarWidth) / 2,
            width: toolbarWidth,
            height: toolbarHeight,
            child: ReaderToolbar(
              key: toolbarKey,
              tool: 'pen',
              color: Colors.black,
              colors: const [
                Colors.black,
                Colors.red,
                Colors.yellow,
                Colors.green,
                Colors.purple,
              ],
              onTool: (_) {},
              onColor: (_) {},
              onCustom: () {},
              onUndo: () {},
              onRedo: () {},
              onSize: (_) {},
              onPenOnly: () {},
              onExport: () {},
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: SelectionBar(
              count: 2,
              onClose: () {},
              onOpen: () {},
            ),
          ),
        ],
      ),
    );
    for (final element in descendants(
      toolbarKey.currentContext! as Element,
    ).where((e) => e.widget is DesignIcon)) {
      final box = element.findRenderObject()! as RenderBox;
      if (box.size.width < 44 || box.size.height < 44)
        throw StateError('Small toolbar target: ${box.size}');
    }
    await capture(toolbar, 'toolbar-${size.width.toInt()}');
    print(
      'PASS toolbar ${size.width.toInt()}: $toolbarWidth x $toolbarHeight, targets >=44, selection fits.',
    );
    final picker = await render(
      'picker-${size.width.toInt()}',
      size,
      false,
      (context) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ColorPickerSheet(initial: Colors.red),
        ),
      ),
    );
    await capture(picker, 'picker-${size.width.toInt()}');
    if (size.width == 320) {
      pickerGesture('Campo de saturação e brilho')
          .onVerticalDragDown!(DragDownDetails(localPosition: Offset(-100, -100)));
      await expectHex('#FFFFFF');
      pickerGesture('Faixa de matiz')
          .onPanDown!(DragDownDetails(localPosition: Offset(10000, 22)));
      pickerGesture('Campo de saturação e brilho')
          .onVerticalDragDown!(DragDownDetails(localPosition: Offset(10000, -100)));
      await expectHex('#FF0000');
      final hueScope = descendants(WidgetsBinding.instance.rootElement!)
          .firstWhere(
            (element) =>
                element.widget is Semantics &&
                (element.widget as Semantics).properties.label ==
                    'Faixa de matiz',
          );
      final hueWidth = (hueScope.findRenderObject()! as RenderBox).size.width;
      pickerGesture('Faixa de matiz').onPanDown!(
        DragDownDetails(localPosition: Offset(14 + (hueWidth - 28) / 3, 22)),
      );
      await expectHex('#00FF00');
      pickerGesture('Campo de saturação e brilho')
          .onVerticalDragDown!(DragDownDetails(localPosition: Offset(10000, 10000)));
      await expectHex('#000000');
      print('PASS HSV interaction: white/red/green/black and drag bounds.');
    }
    print(
      'PASS picker ${size.width.toInt()}: portrait/landscape layout has no overflow.',
    );
  }
  for (final size in [
    const Size(320, 640),
    const Size(834, 1194),
    const Size(914, 360),
  ]) {
    final empty = await render(
      'empty-${size.width.toInt()}',
      size,
      false,
      (context) => LibraryLayout(
        brand: const NotivoWordmark(),
        onCreate: () {},
        cards: const [],
        bottomPadding: 120,
      ),
    );
    await capture(empty, 'empty-${size.width.toInt()}');
    final inset = size.width == 320
        ? const EdgeInsets.only(bottom: 280)
        : EdgeInsets.zero;
    final actionKey = GlobalKey();
    final sheet = await render(
      'sheet-${size.width.toInt()}',
      size,
      false,
      (context) => Padding(
        padding: inset,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AppSheet(
              title: 'Nova coleção',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TextField(
                    decoration: InputDecoration(labelText: 'Nome'),
                  ),
                  for (var i = 0; i < 12; i++)
                    CheckboxListTile(
                      value: false,
                      onChanged: (_) {},
                      title: Text('Coleção $i'),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () {}, child: const Text('Cancelar')),
                FilledButton(
                  key: actionKey,
                  onPressed: () {},
                  child: const Text('Concluir'),
                ),
              ],
            ),
          ),
        ),
      ),
      insets: inset,
    );
    final action = actionKey.currentContext!.findRenderObject()! as RenderBox;
    final bottom = action
        .localToGlobal(Offset(0, action.size.height), ancestor: sheet)
        .dy;
    if (bottom > size.height - inset.bottom + .01)
      throw StateError('Sheet action covered by keyboard');
    await capture(sheet, 'sheet-${size.width.toInt()}');
    print(
      'PASS empty library and scrollable bottom sheet ${size.width.toInt()}: actions visible above keyboard.',
    );
  }
  print('PASS responsive rendering, selection and bottom sheet checks.');
  exit(0);
}
