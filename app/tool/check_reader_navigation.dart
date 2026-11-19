import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../lib/design.dart';
import '../lib/main.dart' as app;
import '../lib/strings.dart' as app_strings;

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const _sqflite = MethodChannel('com.tekartik.sqflite');

void _expect(bool value, String message) {
  if (!value) throw StateError(message);
}

Iterable<Element> _elements(Element root) sync* {
  yield root;
  final children = <Element>[];
  root.visitChildElements(children.add);
  for (final child in children) {
    yield* _elements(child);
  }
}

List<Widget> _widgets() =>
    _elements(WidgetsBinding.instance.rootElement!)
        .map((element) => element.widget)
        .toList();

Future<void> _frame() async {
  WidgetsBinding.instance.scheduleFrame();
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(Duration.zero);
}

Future<void> _settle() async {
  for (var i = 0; i < 26; i++) await _frame();
}

Future<void> _waitUntil(bool Function() condition, String message) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    await _frame();
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException(message);
}

class _FixturePdfBackend implements PdfrxEntryFunctions {
  @override
  Future<void> init() async {}

  @override
  Future<T> suspendPdfiumWorkerDuringAction<T>(
    FutureOr<T> Function() action,
  ) async => await action();

  @override
  Future<PdfDocument> openFile(
    String filePath, {
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = false,
  }) => Future<PdfDocument>.error(
    StateError('Fixture PDF intentionally missing'),
  );

  @override
  PdfrxBackendType get backendType => PdfrxBackendType.mock;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _tapIcon(String label) async {
  final icon = _widgets().whereType<DesignIcon>().firstWhere(
    (item) => item.label == label,
  );
  icon.onPressed?.call();
  await _settle();
}

Future<void> _tapLastIcon(String label) async {
  final icon = _widgets().whereType<DesignIcon>().lastWhere(
    (item) => item.label == label,
  );
  icon.onPressed?.call();
  await _settle();
}

Future<void> _openCollection() async {
  final card = _widgets().whereType<CollectionCard>().firstWhere(
    (item) => item.name == 'Coleção de teste',
  );
  card.onOpen();
  await _settle();
  _expect(
    _widgets().whereType<ScoreRow>().any(
      (row) => row.name == 'Partitura adicionada',
    ),
    'Collection picker did not open its score list',
  );
}

Future<void> _pickAdditionalScore() async {
  await _openCollection();
  final row = _widgets().whereType<ScoreRow>().firstWhere(
    (item) => item.name == 'Partitura adicionada',
  );
  row.onSelect();
  await _settle();
  final bar = _widgets().whereType<SelectionBar>().first;
  bar.onOpen!();
  await _settle();
}

Future<void> main() async {
  final binding = LiveTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  sqflite.databaseFactory = sqflite.databaseFactorySqflitePlugin;
  PdfrxEntryFunctions.instance = _FixturePdfBackend();
  final view = binding.platformDispatcher.views.first as TestFlutterView;
  view.devicePixelRatio = 1;
  view.physicalSize = const Size(914, 360);

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    _pathProvider,
    (call) async => 'C:/notivo-reader-navigation',
  );
  messenger.setMockMethodCallHandler(_sqflite, (call) async {
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
    final sql = (args['sql'] as String? ?? '').toLowerCase();
    switch (call.method) {
      case 'openDatabase':
        return {'id': 1};
      case 'execute':
      case 'closeDatabase':
      case 'options':
      case 'debug':
        return null;
      case 'insert':
        return 1;
      case 'update':
        return 1;
      case 'query':
        if (sql.contains('from collections')) {
          return {
            'columns': ['id', 'name', 'color', 'icon', 'sort_order'],
            'rows': [
              <Object?>[1, 'Coleção de teste', '#6D3BD2', 'music', 0],
            ],
          };
        }
        if (sql.contains('from scores')) {
          return {
            'columns': [
              'id',
              'name',
              'path',
              'collection_id',
              'collection_name',
            ],
            'rows': [
              <Object?>[
                20,
                'Partitura adicionada',
                'C:/missing-notivo-test.pdf',
                1,
                'Coleção de teste',
              ],
            ],
          };
        }
        return <Object?>[];
      default:
        throw MissingPluginException(
          'Unexpected sqflite method ${call.method}',
        );
    }
  });

  final layoutErrors = <String>[];
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    layoutErrors.add(message);
    debugPrint('Reader harness framework error: $message');
  };

  const initial = app.Score(
    10,
    'Partitura inicial',
    'C:/missing-initial.pdf',
    [],
    [],
  );
  runApp(
    MaterialApp(
      locale: const Locale('pt'),
      supportedLocales: app_strings.notivoSupportedLocales,
      localizationsDelegates: app_strings.notivoLocalizationDelegates,
      home: app.ReaderScreen(initial: const [initial], index: 0),
    ),
  );

  await _waitUntil(
    () => _widgets().whereType<DesignIcon>().any(
      (icon) => icon.label == 'Abrir outra partitura',
    ),
    'Reader top bar did not appear',
  );
  final plus = _widgets().whereType<DesignIcon>().firstWhere(
    (icon) => icon.label == 'Abrir outra partitura',
  );
  final plusElement = _elements(WidgetsBinding.instance.rootElement!)
      .firstWhere((element) => identical(element.widget, plus));
  final plusBox = plusElement.findRenderObject()! as RenderBox;
  _expect(
    plusBox.localToGlobal(Offset.zero).dy < 72,
    'Add-partitura control is not in the top header',
  );
  _expect(
    _widgets().whereType<DesignIcon>().any((icon) => icon.label == 'Caneta'),
    'Reader drawing toolbar is missing',
  );
  _expect(
    layoutErrors.isEmpty,
    'Landscape reader overflowed: ${layoutErrors.join('\n')}',
  );

  await _tapIcon('Abrir outra partitura');
  await _waitUntil(
    () => _widgets().whereType<CollectionCard>().isNotEmpty,
    'Additional-score picker did not show collections',
  );
  await _tapIcon('Voltar');
  _expect(
    !_widgets().whereType<Text>().any(
      (text) => text.data == 'Partitura adicionada',
    ),
    'Canceling the picker unexpectedly added a tab',
  );
  _expect(
    _widgets().whereType<Text>().any(
      (text) => text.data == 'Partitura inicial',
    ),
    'Canceling picker did not return to the reader',
  );

  await _tapIcon('Abrir outra partitura');
  await _waitUntil(
    () => _widgets().whereType<CollectionCard>().isNotEmpty,
    'Second picker did not show collections',
  );
  await _openCollection();
  final cancelPicker = _widgets().whereType<DesignIcon>().firstWhere(
    (icon) => icon.label == 'Voltar',
  );
  _expect(
    cancelPicker.onPressed != null,
    'Collection score list has no back/cancel action',
  );
  // Go back from the list to its collection grid, then cancel the picker route.
  cancelPicker.onPressed!.call();
  await _settle();
  await _tapIcon('Voltar');
  _expect(
    !_widgets().whereType<Text>().any(
      (text) => text.data == 'Partitura adicionada',
    ),
    'Canceling after browsing collections added a tab',
  );

  await _tapIcon('Abrir outra partitura');
  await _waitUntil(
    () => _widgets().whereType<CollectionCard>().isNotEmpty,
    'Confirm picker did not show collections',
  );
  await _pickAdditionalScore();
  await _waitUntil(
    () => _widgets().whereType<Text>().any(
      (text) => text.data == 'Partitura adicionada',
    ),
    'Confirming picker did not add a reader tab',
  );

  // Closing is immediate; the snackbar's Undo brings the tab back.
  await _tapLastIcon('Fechar aba');
  await _waitUntil(
    () => !_widgets().whereType<Text>().any(
      (text) => text.data == 'Partitura adicionada',
    ),
    'Closing did not remove the extra tab',
  );
  _widgets().whereType<SnackBarAction>().first.onPressed();
  await _waitUntil(
    () => _widgets().whereType<Text>().any(
      (text) => text.data == 'Partitura adicionada',
    ),
    'Undo did not restore the closed tab',
  );
  ScaffoldMessenger.of(
    _elements(WidgetsBinding.instance.rootElement!).firstWhere(
      (element) => element.widget is Scaffold,
    ),
  ).hideCurrentSnackBar();
  await _settle();
  await _tapLastIcon('Fechar aba');
  await _waitUntil(
    () => !_widgets().whereType<Text>().any(
      (text) => text.data == 'Partitura adicionada',
    ),
    'Closing again did not remove the extra tab',
  );
  _expect(
    _widgets().whereType<Text>().any(
      (text) => text.data == 'Partitura inicial',
    ),
    'Closing extra tab removed the original reader tab',
  );
  _expect(
    layoutErrors.isEmpty,
    'Landscape reader overflowed during picker/close flows',
  );

  view.physicalSize = const Size(320, 640);
  await _settle();
  for (final element in _elements(WidgetsBinding.instance.rootElement!)) {
    if (element.widget is! DesignIcon) continue;
    final box = element.findRenderObject()! as RenderBox;
    _expect(
      box.localToGlobal(Offset.zero).dy + box.size.height <= 164,
      'Reader placed a control below the top toolbar',
    );
  }
  await _tapIcon('Caneta');
  _expect(
    !_widgets().whereType<PdfViewer>().first.params.panEnabled,
    'Drawing mode lets PDF pan underneath the stroke',
  );
  await _tapIcon('Navegar');
  _expect(
    _widgets().whereType<PdfViewer>().first.params.panEnabled,
    'Navigate mode did not restore PDF panning',
  );
  await _tapIcon('Recolher abas e ferramentas');
  _expect(
    !_widgets().whereType<DesignIcon>().any((icon) => icon.label == 'Caneta'),
    'Unified collapse left drawing tools visible',
  );
  _expect(
    !_widgets().whereType<DesignIcon>().any(
      (icon) => icon.label == 'Abrir outra partitura',
    ),
    'Unified collapse left tabs visible',
  );
  await _tapIcon('Mostrar abas e ferramentas');
  _expect(
    _widgets().whereType<DesignIcon>().any((icon) => icon.label == 'Caneta'),
    'Unified reveal did not restore tools',
  );
  _expect(layoutErrors.isEmpty, 'Phone reader had framework errors');
  print(
    'PASS reader at 914x360 and 320x640: controls only at top; unified collapse/reveal; pen/navigation modes.',
  );
  print('PASS collection picker cancel/accept and tab close with undo.');
  exit(0);
}
