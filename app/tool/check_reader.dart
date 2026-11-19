import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../lib/design.dart';
import '../lib/main.dart' as app;

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const _sqflite = MethodChannel('com.tekartik.sqflite');

Map<String, Object?>? savedAnnotation;
final savedPreferences = <String, String>{};
int _pointerId = 1;

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> _frame() async {
  WidgetsBinding.instance.scheduleFrame();
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(Duration.zero);
}

Future<void> _waitUntil(bool Function() condition, String message) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await _frame();
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException(message);
}

Future<void> _stroke(PointerDeviceKind kind, Offset start, Offset end) async {
  final pointer = TestPointer(_pointerId++, kind);
  TestWidgetsFlutterBinding.instance.handlePointerEventForSource(
    pointer.down(start),
    source: TestBindingEventSource.test,
  );
  TestWidgetsFlutterBinding.instance.handlePointerEventForSource(
    pointer.move(end),
    source: TestBindingEventSource.test,
  );
  TestWidgetsFlutterBinding.instance.handlePointerEventForSource(
    pointer.up(),
    source: TestBindingEventSource.test,
  );
  await _frame();
}

class _Harness extends StatefulWidget {
  const _Harness({super.key});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final padKey = GlobalKey();
  String tool = 'pen';
  Color color = Colors.black;
  int backgroundPointerDowns = 0;
  bool showPad = true;

  dynamic get pad => padKey.currentState;

  void updateTool(String value, {Color? nextColor}) {
    setState(() {
      tool = value;
      if (nextColor != null) color = nextColor;
    });
  }

  void remountPad() {
    setState(() => showPad = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => showPad = true);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => backgroundPointerDowns++,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
          if (showPad)
            Positioned.fill(
              child: app.AnnotationPad(
                key: padKey,
                scoreId: 23,
                page: 1,
                tool: tool,
                color: color,
              ),
            ),
        ],
      ),
    ),
  );
}

Future<void> main() async {
  LiveTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  sqflite.databaseFactory = sqflite.databaseFactorySqflitePlugin;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_pathProvider, (call) async {
    return 'C:/notivo-test-support';
  });
  messenger.setMockMethodCallHandler(_sqflite, (call) async {
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
    final sql = (args['sql'] as String? ?? '').toLowerCase();
    debugPrint('mock sqflite: ${call.method} $args');
    switch (call.method) {
      case 'openDatabase':
        return {'id': 1};
      case 'execute':
      case 'closeDatabase':
      case 'options':
      case 'debug':
        return null;
      case 'insert':
        if (sql.contains('into annotations')) {
          final values = (args['arguments'] as List).cast<Object?>();
          savedAnnotation = {
            'score_id': values[0],
            'page': values[1],
            'data': values[2],
            'history': values[3],
            'last_edited': values[4],
          };
        }
        if (sql.contains('into preferences')) {
          final values = (args['arguments'] as List).cast<Object?>();
          savedPreferences[values[0]! as String] = values[1]! as String;
        }
        return 1;
      case 'query':
        if (sql.contains('from preferences')) {
          final values = (args['arguments'] as List?)?.cast<Object?>() ?? [];
          final key = values.isEmpty ? null : values.first as String?;
          final value = key == null ? null : savedPreferences[key];
          if (key == null || value == null) return <Object?>[];
          return {
            'columns': ['key', 'value'],
            'rows': [
              <Object?>[key, value],
            ],
          };
        }
        if (sql.contains('from collections') || sql.contains('from scores')) {
          return <Object?>[];
        }
        if (!sql.contains('from annotations') || savedAnnotation == null) {
          return <Object?>[];
        }
        if (sql.contains('last_edited')) {
          return {
            'columns': ['last_edited'],
            'rows': [
              <Object?>[savedAnnotation!['last_edited']],
            ],
          };
        }
        if (sql.contains('history')) {
          return {
            'columns': ['history'],
            'rows': [
              <Object?>[savedAnnotation!['history']],
            ],
          };
        }
        return {
          'columns': ['score_id', 'page', 'data', 'history', 'last_edited'],
          'rows': [
            <Object?>[
              savedAnnotation!['score_id'],
              savedAnnotation!['page'],
              savedAnnotation!['data'],
              savedAnnotation!['history'],
              savedAnnotation!['last_edited'],
            ],
          ],
        };
      case 'update':
        return 1;
      default:
        throw MissingPluginException(
          'Unexpected sqflite method ${call.method}',
        );
    }
  });

  final hostKey = GlobalKey<_HarnessState>();
  runApp(MaterialApp(home: _Harness(key: hostKey)));
  await _waitUntil(
    () => hostKey.currentState!.pad.ready == true,
    'AnnotationPad did not load its mocked database',
  );
  final host = hostKey.currentState!;

  await _stroke(
    PointerDeviceKind.touch,
    const Offset(40, 50),
    const Offset(160, 50),
  );
  _expect(host.pad.strokes.length == 1, 'Touch did not create a pen stroke');
  await host.pad.flush();
  final savedTouch = (jsonDecode(savedAnnotation!['data']! as String) as List);
  _expect(
    savedTouch.length == 1 && savedTouch.first['tool'] == 'pen',
    'Touch stroke was not persisted',
  );

  await _stroke(
    PointerDeviceKind.mouse,
    const Offset(40, 90),
    const Offset(160, 90),
  );
  _expect(host.pad.strokes.length == 2, 'Mouse did not create a pen stroke');
  await _stroke(
    PointerDeviceKind.stylus,
    const Offset(40, 140),
    const Offset(160, 140),
  );
  _expect(host.pad.strokes.length == 3, 'Stylus did not create a pen stroke');

  host.updateTool('highlighter', nextColor: Colors.red);
  await _frame();
  await _stroke(
    PointerDeviceKind.touch,
    const Offset(40, 190),
    const Offset(160, 190),
  );
  _expect(
    host.pad.strokes.last['tool'] == 'highlighter',
    'Highlighter tool was not recorded',
  );
  await host.pad.flush();
  final savedHighlighter =
      jsonDecode(savedAnnotation!['data']! as String) as List;
  _expect(
    savedHighlighter.length == 4 &&
        savedHighlighter.last['tool'] == 'highlighter',
    'Highlighter stroke was not persisted',
  );
  _expect(
    savedHighlighter.last['color'] == Colors.red.toARGB32(),
    'Highlighter RGB color was not preserved',
  );

  await host.pad.undo();
  _expect(
    host.pad.strokes.length == 3,
    'Undo did not restore the previous stroke list',
  );
  await host.pad.flush();
  host.remountPad();
  await _frame();
  await _frame();
  await _waitUntil(() => host.pad.ready == true, 'Remounted pad did not load');
  _expect(
    host.pad.strokes.length == 3,
    'Saved annotations did not survive remount',
  );

  host.updateTool('eraser');
  await _frame();
  await _stroke(
    PointerDeviceKind.touch,
    const Offset(100, 50),
    const Offset(100, 50),
  );
  _expect(
    host.pad.strokes.length == 2,
    'Eraser did not remove the nearby pen stroke',
  );
  await host.pad.flush();
  final savedErased = jsonDecode(savedAnnotation!['data']! as String) as List;
  _expect(savedErased.length == 2, 'Eraser result was not persisted');

  final backgroundBefore = host.backgroundPointerDowns;
  final annotationsBefore = host.pad.strokes.length;
  host.updateTool('navigate');
  await _frame();
  await _stroke(
    PointerDeviceKind.touch,
    const Offset(80, 240),
    const Offset(180, 250),
  );
  _expect(
    host.backgroundPointerDowns > backgroundBefore,
    'Navigate mode did not pass pointer events through',
  );
  _expect(
    host.pad.strokes.length == annotationsBefore,
    'Navigate mode wrote annotation data',
  );

  await _checkAppSettings();
  print(
    'PASS touch, mouse and stylus drawing; highlighter color/tool; erase; undo; persistence/remount; navigate pass-through.',
  );
  print('PASS menu: dark theme and English locale persist across app restart.');
  exit(0);
}

Iterable<Element> _elements(Element root) sync* {
  yield root;
  final children = <Element>[];
  root.visitChildElements(children.add);
  for (final child in children) {
    yield* _elements(child);
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) await _frame();
}

Future<void> _checkAppSettings() async {
  runApp(const SizedBox.shrink());
  await _settle();
  runApp(const app.NotivoApp());
  await _waitUntil(
    () =>
        _elements(WidgetsBinding.instance.rootElement!)
            .map((element) => element.widget)
            .whereType<DesignIcon>()
            .any((icon) => icon.label == 'Configurações'),
    'Library settings button did not appear',
  );
  var menu = _elements(WidgetsBinding.instance.rootElement!)
      .map((element) => element.widget)
      .whereType<DesignIcon>()
      .firstWhere((icon) => icon.label == 'Configurações');
  menu.onPressed!();
  await _settle();
  final themeChoice = _elements(WidgetsBinding.instance.rootElement!)
      .map((element) => element.widget)
      .whereType<Segmented<ThemeMode>>()
      .first;
  themeChoice.onChanged(ThemeMode.dark);
  await _waitUntil(
    () => savedPreferences['theme'] == 'dark',
    'Dark mode preference was not persisted',
  );

  await _settle();
  menu = _elements(WidgetsBinding.instance.rootElement!)
      .map((element) => element.widget)
      .whereType<DesignIcon>()
      .firstWhere((icon) => icon.label == 'Configurações');
  menu.onPressed!();
  await _settle();
  final language = _elements(WidgetsBinding.instance.rootElement!)
      .map((element) => element.widget)
      .whereType<Segmented<String>>()
      .first;
  language.onChanged('en');
  await _waitUntil(
    () => savedPreferences['language'] == 'en',
    'English preference was not persisted',
  );

  runApp(const SizedBox.shrink());
  await _settle();
  runApp(const app.NotivoApp());
  await _waitUntil(() {
    final root = WidgetsBinding.instance.rootElement!;
    final translated = _elements(root)
        .map((element) => element.widget)
        .whereType<Text>()
        .any((text) => text.data == 'New collection');
    if (!translated) return false;
    final textElement = _elements(root).firstWhere(
      (element) =>
          element.widget is Text &&
          (element.widget as Text).data == 'New collection',
    );
    return Theme.of(textElement).brightness == Brightness.dark;
  }, 'App did not restore dark theme and English locale after restart');
}
