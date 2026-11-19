import 'dart:convert';

import 'brand.dart';
import 'design.dart';
import 'collection_editor.dart';
import 'color_picker.dart';
import 'reader_toolbar.dart';
import 'selection.dart';
import 'sheets.dart';
import 'strings.dart';
import 'text.dart';

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

const violet = Color(0xff6d3bd2);
const noteColors = [
  Color(0xff000000),
  Color(0xffe53935),
  Color(0xfffacc15),
  Color(0xff22a559),
  violet,
];

Color _color(String value) =>
    Color(int.parse(value.replaceFirst('#', 'ff'), radix: 16));
String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

class Collection {
  const Collection(this.id, this.name, this.color, this.icon, this.iconColor);
  final int id;
  final String name;
  final String color;
  final String icon;
  final String iconColor;
}

class Score {
  const Score(
    this.id,
    this.name,
    this.path,
    this.collections,
    this.collectionIds,
  );
  final int id;
  final String name;
  final String path;
  final List<String> collections;
  final List<int> collectionIds;
}

class Store {
  Store._();
  static final instance = Store._();
  late final Future<Database> _db = _open();

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final db = await openDatabase(
      p.join(dir.path, 'notivo.db'),
      version: 3,
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE collections ADD COLUMN icon_color TEXT NOT NULL DEFAULT '#FFFFFF'",
          );
          await db.execute(
            "UPDATE collections SET icon_color='#2E1A6B' WHERE upper(color)='#C9B6F5'",
          );
        }
        if (oldVersion < 2) {
          const defaults = [
            (2, 'Banda', 'drum', '#E53935', '#2E1A6B'),
            (3, 'Igreja', 'church', '#22A559', '#C9B6F5'),
            (4, 'Estudos', 'book-open', '#FACC15', '#8A5CE8'),
          ];
          for (final item in defaults) {
            await db.update(
              'collections',
              {'color': item.$5},
              where: 'id=? AND name=? AND icon=? AND color=?',
              whereArgs: [item.$1, item.$2, item.$3, item.$4],
            );
          }
        }
      },
      onCreate: (db, _) async {
        await db.execute(
          "CREATE TABLE collections(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,color TEXT NOT NULL,icon TEXT NOT NULL,sort_order INTEGER NOT NULL,icon_color TEXT NOT NULL DEFAULT '#FFFFFF')",
        );
        await db.execute(
          'CREATE TABLE scores(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,original_name TEXT NOT NULL,path TEXT NOT NULL UNIQUE,imported_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE collection_scores(collection_id INTEGER NOT NULL,score_id INTEGER NOT NULL,PRIMARY KEY(collection_id,score_id),FOREIGN KEY(collection_id) REFERENCES collections(id) ON DELETE CASCADE,FOREIGN KEY(score_id) REFERENCES scores(id) ON DELETE CASCADE)',
        );
        await db.execute(
          'CREATE TABLE annotations(score_id INTEGER NOT NULL,page INTEGER NOT NULL,data TEXT NOT NULL,history TEXT NOT NULL,last_edited TEXT NOT NULL,PRIMARY KEY(score_id,page),FOREIGN KEY(score_id) REFERENCES scores(id) ON DELETE CASCADE)',
        );
        await db.execute(
          'CREATE TABLE preferences(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
        );
        const seeds = [
          ('Orquestra', '#6D3BD2', 'music'),
          ('Banda', '#2E1A6B', 'drum'),
          ('Igreja', '#C9B6F5', 'church'),
          ('Estudos', '#8A5CE8', 'book-open'),
        ];
        for (var i = 0; i < seeds.length; i++) {
          final item = seeds[i];
          await db.insert('collections', {
            'name': item.$1,
            'color': item.$2,
            'icon': item.$3,
            'icon_color': item.$2 == '#C9B6F5' ? '#2E1A6B' : '#FFFFFF',
            'sort_order': i,
          });
        }
      },
    );
    await db.execute('PRAGMA foreign_keys = ON');
    return db;
  }

  Future<List<Collection>> collections() async {
    final rows = await (await _db).query(
      'collections',
      orderBy: 'sort_order,id',
    );
    return rows
        .map(
          (r) => Collection(
            r['id'] as int,
            r['name'] as String,
            r['color'] as String,
            r['icon'] as String,
            r['icon_color'] as String,
          ),
        )
        .toList();
  }

  Future<int> saveCollection({
    int? id,
    required String name,
    required String color,
    required String icon,
    required String iconColor,
  }) async {
    final db = await _db;
    if (id == null)
      return db.insert('collections', {
        'name': name,
        'color': color,
        'icon': icon,
        'icon_color': iconColor,
        'sort_order': DateTime.now().millisecondsSinceEpoch,
      });
    await db.update(
      'collections',
      {'name': name, 'color': color, 'icon': icon, 'icon_color': iconColor},
      where: 'id=?',
      whereArgs: [id],
    );
    return id;
  }

  Future<void> deleteCollections(Iterable<int> ids) async {
    await (await _db).transaction((txn) async {
      for (final id in ids) {
        await txn.delete(
          'collection_scores',
          where: 'collection_id=?',
          whereArgs: [id],
        );
        await txn.delete('collections', where: 'id=?', whereArgs: [id]);
      }
    });
  }

  Future<void> removeFromCollection(int collectionId, Iterable<int> scoreIds) async {
    await (await _db).transaction((txn) async {
      for (final id in scoreIds) {
        await txn.delete(
          'collection_scores',
          where: 'collection_id=? AND score_id=?',
          whereArgs: [collectionId, id],
        );
      }
    });
  }

  Future<List<Score>> scores({
    int? collectionId,
    String search = '',
    bool recent = false,
    bool reverse = false,
  }) async {
    final rows = await (await _db).rawQuery('''
      SELECT s.id,s.name,s.path,s.imported_at,c.id AS collection_id,c.name AS collection_name FROM scores s
      LEFT JOIN collection_scores cs ON cs.score_id=s.id
      LEFT JOIN collections c ON c.id=cs.collection_id
      ${collectionId == null ? '' : 'WHERE s.id IN (SELECT score_id FROM collection_scores WHERE collection_id=?)'}
      ORDER BY s.name COLLATE NOCASE
    ''', collectionId == null ? null : [collectionId]);
    final grouped = <int, Map<String, Object?>>{};
    for (final row in rows) {
      final id = row['id']! as int;
      final score = grouped.putIfAbsent(
        id,
        () => {...row, 'collections': <String>[], 'collectionIds': <int>[]},
      );
      if (row['collection_name'] != null) {
        (score['collections']! as List<String>).add(
          row['collection_name']! as String,
        );
        (score['collectionIds']! as List<int>).add(
          row['collection_id']! as int,
        );
      }
    }
    final query = fold(search.trim());
    final list = grouped.values
        .where((r) => fold(r['name']! as String).contains(query))
        .toList();
    list.sort(
      (a, b) {
        final r = recent
            ? (b['imported_at']! as String).compareTo(a['imported_at']! as String)
            : naturalCompare(a['name']! as String, b['name']! as String);
        return reverse ? -r : r;
      },
    );
    return list
        .map(
          (r) => Score(
            r['id']! as int,
            r['name']! as String,
            r['path']! as String,
            r['collections']! as List<String>,
            r['collectionIds']! as List<int>,
          ),
        )
        .toList();
  }

  Future<void> importPdf(PlatformFile file, int? collectionId) async {
    final sourcePath = file.path;
    if (sourcePath == null || !file.name.toLowerCase().endsWith('.pdf')) return;
    final source = File(sourcePath);
    final handle = await source.open();
    late final String header;
    try {
      header = latin1.decode(await handle.read(1024), allowInvalid: true);
    } finally {
      await handle.close();
    }
    if (!header.contains('%PDF-')) {
      throw FormatException('${file.name} não contém um PDF válido.');
    }
    final dir = await getApplicationSupportDirectory();
    final id = DateTime.now().microsecondsSinceEpoch;
    final target = File(p.join(dir.path, '$id.pdf'));
    try {
      await source.copy(target.path);
      final db = await _db;
      await db.transaction((txn) async {
        final scoreId = await txn.insert('scores', {
          'name': p.basenameWithoutExtension(file.name),
          'original_name': file.name,
          'path': target.path,
          'imported_at': DateTime.now().toIso8601String(),
        });
        if (collectionId != null) {
          await txn.insert('collection_scores', {
            'collection_id': collectionId,
            'score_id': scoreId,
          });
        }
      });
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<void> renameScore(int id, String name) => _db.then(
    (db) => db.update('scores', {'name': name}, where: 'id=?', whereArgs: [id]),
  );

  Future<String?> preference(String key) async {
    final row = await (await _db).query(
      'preferences',
      where: 'key=?',
      whereArgs: [key],
      limit: 1,
    );
    return row.isEmpty ? null : row.first['value'] as String;
  }

  Future<void> setPreference(String key, String value) async {
    await (await _db).insert('preferences', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setScoreCollections(int scoreId, Set<int> collectionIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'collection_scores',
        where: 'score_id=?',
        whereArgs: [scoreId],
      );
      for (final id in collectionIds)
        await txn.insert('collection_scores', {
          'collection_id': id,
          'score_id': scoreId,
        });
    });
  }

  Future<List<Map<String, dynamic>>> annotations(int scoreId, int page) async {
    final row = await (await _db).query(
      'annotations',
      where: 'score_id=? AND page=?',
      whereArgs: [scoreId, page],
      limit: 1,
    );
    return row.isEmpty
        ? []
        : List<Map<String, dynamic>>.from(
            jsonDecode(row.first['data']! as String),
          );
  }

  Future<void> saveAnnotations(
    int scoreId,
    int page,
    List<Map<String, dynamic>> data,
    List<List<Map<String, dynamic>>> history,
    DateTime lastEdited,
  ) async {
    await (await _db).insert('annotations', {
      'score_id': scoreId,
      'page': page,
      'data': jsonEncode(data),
      'history': jsonEncode(history),
      'last_edited': lastEdited.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DateTime?> lastAnnotationEdit(int scoreId, int page) async {
    final row = await (await _db).query(
      'annotations',
      columns: ['last_edited'],
      where: 'score_id=? AND page=?',
      whereArgs: [scoreId, page],
      limit: 1,
    );
    return row.isEmpty
        ? null
        : DateTime.tryParse(row.first['last_edited']! as String);
  }

  Future<List<List<Map<String, dynamic>>>> history(
    int scoreId,
    int page,
  ) async {
    final row = await (await _db).query(
      'annotations',
      columns: ['history'],
      where: 'score_id=? AND page=?',
      whereArgs: [scoreId, page],
      limit: 1,
    );
    return row.isEmpty
        ? []
        : (jsonDecode(row.first['history']! as String) as List)
              .map((e) => List<Map<String, dynamic>>.from(e))
              .toList();
  }

  /// Library as JSON with PDFs embedded in base64.
  // shortcut: whole backup is built in memory, stream to a file if libraries reach hundreds of MB.
  Future<String> exportBackup({required bool annotations}) async {
    final db = await _db;
    final scores = <Map<String, Object?>>[];
    for (final row in await db.query('scores')) {
      final id = row['id']! as int;
      scores.add({
        'name': row['name'],
        'original_name': row['original_name'],
        'imported_at': row['imported_at'],
        'collections': [
          for (final link in await db.query(
            'collection_scores',
            where: 'score_id=?',
            whereArgs: [id],
          ))
            link['collection_id'],
        ],
        'pdf': base64Encode(await File(row['path']! as String).readAsBytes()),
        if (annotations)
          'annotations': await db.query(
            'annotations',
            columns: ['page', 'data', 'history', 'last_edited'],
            where: 'score_id=?',
            whereArgs: [id],
          ),
      });
    }
    return jsonEncode({
      'app': 'notivo',
      'version': 1,
      'collections': await db.query(
        'collections',
        columns: ['id', 'name', 'color', 'icon', 'icon_color'],
        orderBy: 'sort_order,id',
      ),
      'scores': scores,
    });
  }

  /// Merges a backup: collections and scores whose name already exists are reused.
  /// Returns how many scores were added.
  Future<int> importBackup(String text) async {
    final data = jsonDecode(text.trim());
    if (data is! Map ||
        data['app'] != 'notivo' ||
        data['collections'] is! List ||
        data['scores'] is! List) {
      throw const FormatException('Backup do Notivo inválido.');
    }
    final hex = RegExp(r'^#[0-9A-Fa-f]{6}$');
    String color(Object? value, String fallback) =>
        value is String && hex.hasMatch(value) ? value : fallback;
    final db = await _db;
    final dir = await getApplicationSupportDirectory();
    final written = <File>[];
    var added = 0;
    try {
      await db.transaction((txn) async {
        final ids = <Object?, int>{};
        var order = DateTime.now().millisecondsSinceEpoch;
        for (final item in data['collections'] as List) {
          final name = (item as Map)['name'] as String;
          final found = await txn.query(
            'collections',
            columns: ['id'],
            where: 'name=?',
            whereArgs: [name],
            limit: 1,
          );
          ids[item['id']] = found.isNotEmpty
              ? found.first['id']! as int
              : await txn.insert('collections', {
                  'name': name,
                  'color': color(item['color'], '#6D3BD2'),
                  'icon': item['icon'] is String ? item['icon'] : 'music',
                  'icon_color': color(item['icon_color'], '#FFFFFF'),
                  'sort_order': order++,
                });
        }
        for (final item in data['scores'] as List) {
          final name = (item as Map)['name'] as String;
          final found = await txn.query(
            'scores',
            columns: ['id'],
            where: 'name=?',
            whereArgs: [name],
            limit: 1,
          );
          late final int scoreId;
          if (found.isNotEmpty) {
            scoreId = found.first['id']! as int;
          } else {
            final bytes = base64Decode(item['pdf'] as String);
            final header = latin1.decode(
              bytes.take(1024).toList(),
              allowInvalid: true,
            );
            if (!header.contains('%PDF-')) {
              throw FormatException('$name não contém um PDF válido.');
            }
            final file = File(
              p.join(
                dir.path,
                '${DateTime.now().microsecondsSinceEpoch}_$added.pdf',
              ),
            );
            written.add(file);
            await file.writeAsBytes(bytes, flush: true);
            scoreId = await txn.insert('scores', {
              'name': name,
              'original_name': item['original_name'] as String? ?? '$name.pdf',
              'path': file.path,
              'imported_at':
                  item['imported_at'] as String? ??
                  DateTime.now().toIso8601String(),
            });
            added++;
            for (final note in item['annotations'] as List? ?? const []) {
              await txn.insert('annotations', {
                'score_id': scoreId,
                'page': (note as Map)['page'] as int,
                'data': note['data'] as String,
                'history': note['history'] as String,
                'last_edited': note['last_edited'] as String,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
          for (final old in item['collections'] as List? ?? const []) {
            final id = ids[old];
            if (id != null) {
              await txn.insert('collection_scores', {
                'collection_id': id,
                'score_id': scoreId,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        }
      });
    } catch (_) {
      for (final file in written) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
    return added;
  }
}

Future<void> openSelectedScores(
  BuildContext context,
  ScoreSelection selection,
) async {
  final all = await Store.instance.scores();
  final scores = all
      .where((score) => selection.value.contains(score.id))
      .toList();
  if (scores.isEmpty || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ReaderScreen(initial: scores, index: 0)),
  );
}

Future<void> chooseScores(
  BuildContext context,
  ScoreSelection selection,
) async {
  final all = await Store.instance.scores();
  if (!context.mounted) return;
  final chosen = {...selection.value};
  final result = await showAppSheet<Set<int>>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => AppSheet(
        title: tr(context, 'Selecionar partituras'),
        child: all.isEmpty
            ? Text(
                tr(
                  context,
                  'Nenhuma partitura importada. Importe um PDF para começar.',
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: all
                    .map(
                      (score) => CheckboxListTile(
                        value: chosen.contains(score.id),
                        title: Text(score.name),
                        subtitle: Text(
                          score.collections.isEmpty
                              ? tr(context, 'Sem coleção')
                              : score.collections.join(' · '),
                        ),
                        onChanged: (value) => setSheet(
                          () => value == true
                              ? chosen.add(score.id)
                              : chosen.remove(score.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(context, 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, chosen),
            child: Text(tr(context, 'Concluir')),
          ),
        ],
      ),
    ),
  );
  if (result != null) selection.replace(result);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  runApp(const NotivoApp());
}

class NotivoApp extends StatefulWidget {
  const NotivoApp({super.key});
  @override
  State<NotivoApp> createState() => _NotivoAppState();
}

class _NotivoAppState extends State<NotivoApp> {
  ThemeMode theme = ThemeMode.light;
  String language = 'pt';
  @override
  void initState() {
    super.initState();
    Store.instance.preference('theme').then((value) {
      if (mounted && value == 'dark') setState(() => theme = ThemeMode.dark);
    });
    Store.instance.preference('language').then((value) {
      if (mounted && (value == 'pt' || value == 'en'))
        setState(() => language = value!);
    });
  }

  void toggleTheme() {
    final dark = theme != ThemeMode.dark;
    setState(() => theme = dark ? ThemeMode.dark : ThemeMode.light);
    Store.instance.setPreference('theme', dark ? 'dark' : 'light');
  }

  void changeLanguage(String value) {
    setState(() => language = value);
    Store.instance.setPreference('language', value);
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: violet,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xffb79cf0) : violet,
          onPrimary: dark ? const Color(0xff2e1a6b) : Colors.white,
          surface: dark ? const Color(0xff14102a) : Colors.white,
          onSurface: dark ? const Color(0xfff1ebff) : const Color(0xff1f1340),
          onSurfaceVariant: dark
              ? const Color(0xffb3a6d9)
              : const Color(0xff5b4d85),
          surfaceContainer: dark ? const Color(0xff1b1636) : Colors.white,
          surfaceContainerHighest: dark
              ? const Color(0xff1f1940)
              : const Color(0xfff4effc),
          outline: dark ? const Color(0xff3f3470) : const Color(0xffd9ccf5),
          outlineVariant: dark
              ? const Color(0xff2e2552)
              : const Color(0xffe6ddf7),
        );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      useMaterial3: true,
      fontFamily: 'Inter',
      splashFactory: NoSplash.splashFactory,
      dividerColor: scheme.outlineVariant,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Notivo',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: theme,
    locale: Locale(language),
    supportedLocales: notivoSupportedLocales,
    localizationsDelegates: notivoLocalizationDelegates,
    home: LibraryScreen(onToggleTheme: toggleTheme, onLanguage: changeLanguage),
  );
}

void showError(BuildContext context, String message, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tr(context, message)}: $error')),
    );

Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showAppSheet<bool>(
      context,
      builder: (ctx) => AppSheet(
        title: tr(ctx, title),
        child: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(ctx, 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(ctx, action)),
          ),
        ],
      ),
    ) ==
    true;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    this.onToggleTheme,
    this.onLanguage,
    this.picking = false,
    this.initialSelection = const [],
  });
  final VoidCallback? onToggleTheme;
  final ValueChanged<String>? onLanguage;
  final bool picking;
  final List<int> initialSelection;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Future<List<Collection>>? future;
  final selection = ScoreSelection();
  // Collections picked by long press, for removal.
  Set<int> picked = {};
  void refresh() => setState(() {
    future = Store.instance.collections();
  });
  void selectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    future = Store.instance.collections();
    selection.replace(widget.initialSelection);
    selection.addListener(selectionChanged);
  }

  @override
  void dispose() {
    selection.removeListener(selectionChanged);
    selection.dispose();
    super.dispose();
  }

  Future<void> openSelection() async {
    if (!widget.picking) return openSelectedScores(context, selection);
    final scores = (await Store.instance.scores())
        .where((score) => selection.value.contains(score.id))
        .toList();
    if (!mounted || scores.isEmpty) return;
    final route = ModalRoute.of(context)!;
    Navigator.popUntil(context, (item) => item == route);
    Navigator.pop(context, scores);
  }

  Future<void> openMenu() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          onToggleTheme: widget.onToggleTheme,
          onLanguage: widget.onLanguage,
        ),
      ),
    );
    if (mounted) refresh();
  }

  void togglePicked(Collection collection) => setState(() {
    picked = {...picked};
    if (!picked.add(collection.id)) picked.remove(collection.id);
  });

  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    return PopScope(
      canPop: picked.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => picked = {});
      },
      child: Scaffold(
        body: SafeArea(
          child: DesignViewport(
            child: Stack(
              children: [
                FutureBuilder<List<Collection>>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.hasError)
                      return Center(
                        child: Text(
                          tr(context, 'Não foi possível abrir a biblioteca.'),
                        ),
                      );
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    return LibraryLayout(
                      brand: NotivoWordmark(
                        fontSize: 40,
                        color: c.dark ? Colors.white : c.tx,
                        markColor: c.mark,
                      ),
                      onMenu: widget.picking
                          ? () => Navigator.pop(context)
                          : openMenu,
                      picking: widget.picking,
                      onCreate: () => editCollection(),
                      onBrowseAll: () => chooseScores(context, selection),
                      bottomPadding: selection.value.isEmpty ? 40 : 120,
                      cards: snap.data!
                          .map(
                            (collection) => _CollectionTile(
                              collection: collection,
                              selected: picked.contains(collection.id),
                              onOpen: picked.isNotEmpty
                                  ? () => togglePicked(collection)
                                  : () => openCollection(collection),
                              onLongPress: widget.picking
                                  ? null
                                  : () => togglePicked(collection),
                              onEdit: () => collectionActions(collection),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                if (picked.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SelectionBar(
                      count: picked.length,
                      onClose: () => setState(() => picked = {}),
                      onDelete: removePicked,
                    ),
                  ),
                if (selection.value.isNotEmpty)
                  Positioned(
                    left: compact ? 12 : 96,
                    right: compact ? 12 : 96,
                    bottom: compact ? 16 : 40,
                    child: SelectionPill(
                      count: selection.value.length,
                      onClear: selection.clear,
                      onOpen: openSelection,
                      onAdd: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr(
                              context,
                              'Abra uma coleção para selecionar mais partituras.',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openCollection(Collection collection) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoreListScreen(
          collection: collection,
          selection: selection,
          onOpenSelection: widget.picking ? openSelection : null,
        ),
      ),
    );
    if (mounted) refresh();
  }

  Future<void> collectionActions(Collection collection) async {
    final action = await showAppSheet<String>(
      context,
      builder: (ctx) => AppSheet(
        title: collection.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: Text(tr(context, 'Editar coleção')),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(
                LucideIcons.trash2,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(tr(context, 'Remover coleção')),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await editCollection(collection);
    if (action == 'remove') await removeCollections([collection]);
  }

  Future<void> removePicked() async {
    final all = await future ?? const <Collection>[];
    await removeCollections(all.where((item) => picked.contains(item.id)));
  }

  Future<void> removeCollections(Iterable<Collection> collections) async {
    final names = collections.map((item) => '“${item.name}”').join(', ');
    if (names.isEmpty) return;
    final confirmed = await confirmSheet(
      context,
      title: 'Remover coleção?',
      message:
          '$names\n${tr(context, 'As partituras e anotações serão mantidas.')}',
      action: 'Remover',
    );
    if (!confirmed || !mounted) return;
    try {
      await Store.instance.deleteCollections(collections.map((c) => c.id));
      if (mounted) {
        picked = {};
        refresh();
      }
    } catch (error) {
      if (mounted)
        showError(context, 'Não foi possível remover a coleção', error);
    }
  }

  Future<void> editCollection([Collection? existing]) async {
    final draft = await showAppSheet<CollectionDraft>(
      context,
      builder: (_) => CollectionEditor(
        title: tr(context, existing == null ? 'Nova coleção' : 'Editar coleção'),
        name: existing?.name ?? '',
        icon: existing?.icon ?? 'music',
        color: _color(existing?.color ?? '#6D3BD2'),
        iconColor: _color(existing?.iconColor ?? '#FFFFFF'),
      ),
    );
    if (draft == null) return;
    try {
      await Store.instance.saveCollection(
        id: existing?.id,
        name: draft.name,
        color: _hex(draft.color),
        icon: draft.icon,
        iconColor: _hex(draft.iconColor),
      );
      if (mounted) refresh();
    } catch (error) {
      if (mounted) showError(context, 'Não foi possível salvar a coleção', error);
    }
  }
}

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, this.onToggleTheme, this.onLanguage});
  final VoidCallback? onToggleTheme;
  final ValueChanged<String>? onLanguage;

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      tr(context, text),
      style: designText(
        13,
        NotivoColors(context).tx2,
        weight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              children: [
                Row(
                  children: [
                    DesignIcon(
                      icon: LucideIcons.chevronLeft,
                      label: 'Voltar',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tr(context, 'Menu'),
                      style: designText(24, c.tx, weight: FontWeight.w700),
                    ),
                  ],
                ),
                _header(context, 'Aparência'),
                SwitchListTile(
                  secondary: const Icon(LucideIcons.moon),
                  title: Text(tr(context, 'Modo escuro')),
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (_) => onToggleTheme?.call(),
                ),
                const Divider(height: 24),
                _header(context, 'Idioma'),
                for (final language in [('pt', 'Português'), ('en', 'English')])
                  RadioListTile<String>(
                    title: Text(language.$2),
                    value: language.$1,
                    groupValue: Localizations.localeOf(context).languageCode,
                    onChanged: (value) {
                      if (value != null) onLanguage?.call(value);
                    },
                  ),
                const Divider(height: 24),
                _header(context, 'Backup'),
                ListTile(
                  leading: const Icon(LucideIcons.databaseBackup),
                  title: Text(tr(context, 'Salvar backup')),
                  subtitle: Text(
                    tr(context, 'Coleções e partituras com os nomes atuais.'),
                  ),
                  onTap: () => saveBackup(context),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.archiveRestore),
                  title: Text(tr(context, 'Restaurar backup')),
                  subtitle: Text(
                    tr(context, 'Escolha o arquivo. Itens com o mesmo nome não são duplicados.'),
                  ),
                  onTap: () => restoreBackup(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> saveBackup(BuildContext context) async {
  var withAnnotations = true;
  final go = await showAppSheet<bool>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => AppSheet(
        title: tr(ctx, 'Salvar backup'),
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: withAnnotations,
          title: Text(tr(ctx, 'Incluir anotações')),
          onChanged: (value) => setSheet(() => withAnnotations = value ?? false),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(ctx, 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(ctx, 'Salvar')),
          ),
        ],
      ),
    ),
  );
  if (go != true || !context.mounted) return;
  try {
    final json = await Store.instance.exportBackup(
      annotations: withAnnotations,
    );
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final file = File(
      p.join((await getTemporaryDirectory()).path, 'notivo-backup-$day.json'),
    );
    await file.writeAsString(json, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  } catch (error) {
    if (context.mounted) showError(context, 'Falha ao salvar backup', error);
  }
}

Future<void> restoreBackup(BuildContext context) async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  final path = picked.isEmpty ? null : picked.first.path;
  if (path == null || !context.mounted) return;
  try {
    final added = await Store.instance.importBackup(
      await File(path).readAsString(),
    );
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr(context, 'Backup restaurado')}: $added ${tr(context, 'partituras')}',
          ),
        ),
      );
  } catch (error) {
    if (context.mounted) showError(context, 'Falha ao restaurar', error);
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.collection,
    required this.onOpen,
    required this.onEdit,
    this.onLongPress,
    this.selected = false,
  });
  final Collection collection;
  final VoidCallback onOpen, onEdit;
  final VoidCallback? onLongPress;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final circle = collection.color.toUpperCase() == '#2E1A6B'
        ? c.banda
        : _color(collection.color);
    return FutureBuilder<List<Score>>(
      future: Store.instance.scores(collectionId: collection.id),
      builder: (context, snapshot) => CollectionCard(
        name: collection.name,
        count: snapshot.data?.length ?? 0,
        icon: collectionIcon(collection.icon),
        color: circle,
        iconColor: _color(collection.iconColor),
        selected: selected,
        onOpen: onOpen,
        onEdit: onEdit,
        onLongPress: onLongPress,
      ),
    );
  }
}

class ScoreListScreen extends StatefulWidget {
  const ScoreListScreen({
    super.key,
    required this.collection,
    required this.selection,
    this.onOpenSelection,
  });
  final Collection collection;
  final ScoreSelection selection;
  final VoidCallback? onOpenSelection;
  @override
  State<ScoreListScreen> createState() => _ScoreListScreenState();
}

class _ScoreListScreenState extends State<ScoreListScreen> {
  final search = TextEditingController();
  Set<int> get selected => widget.selection.value;
  Future<List<Score>>? future;
  // Sort cycles on tap: name ascending, name descending, newest, oldest.
  int sort = 0;
  static const _sorts = [
    (LucideIcons.arrowDown01, 'Nome / número crescente'),
    (LucideIcons.arrowDown10, 'Nome / número decrescente'),
    (LucideIcons.clockArrowDown, 'Mais recentes'),
    (LucideIcons.clockArrowUp, 'Menos recentes'),
  ];
  // Long press shows the top bar that removes selected scores from this collection.
  bool removing = false;
  List<Score> shown = const [];
  void refresh() => setState(() {
    future = Store.instance.scores(
      collectionId: widget.collection.id,
      search: search.text,
      recent: sort >= 2,
      reverse: sort.isOdd,
    );
  });
  void selectionChanged() {
    if (!mounted) return;
    setState(() {
      // Unselecting the last score closes the remove bar.
      if (!shown.any((s) => selected.contains(s.id))) removing = false;
    });
  }

  @override
  void initState() {
    super.initState();
    future = Store.instance.scores(collectionId: widget.collection.id);
    widget.selection.addListener(selectionChanged);
  }

  @override
  void dispose() {
    widget.selection.removeListener(selectionChanged);
    search.dispose();
    super.dispose();
  }

  Future<void> importFiles() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked.isEmpty) return;
    try {
      for (final file in picked) {
        await Store.instance.importPdf(file, widget.collection.id);
      }
    } catch (error) {
      if (mounted) showError(context, 'Não foi possível importar', error);
    }
    if (mounted) refresh();
  }

  Future<void> rename(Score score) async {
    final name = await showAppSheet<String>(
      context,
      builder: (_) => _RenameSheet(initial: score.name),
    );
    if (name == null) return;
    try {
      await Store.instance.renameScore(score.id, name);
      if (mounted) refresh();
    } catch (error) {
      if (mounted) showError(context, 'Não foi possível renomear', error);
    }
  }

  Future<void> organize(Score score) async {
    final all = await Store.instance.collections();
    if (!mounted) return;
    final chosen = score.collectionIds.toSet();
    final saved = await showAppSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AppSheet(
          title: tr(context, 'Coleções'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: all
                .map(
                  (collection) => CheckboxListTile(
                    value: chosen.contains(collection.id),
                    title: Text(collection.name),
                    onChanged: (value) => setSheet(
                      () => value == true
                          ? chosen.add(collection.id)
                          : chosen.remove(collection.id),
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(context, 'Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr(context, 'Concluir')),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await Store.instance.setScoreCollections(score.id, chosen);
      if (mounted) refresh();
    } catch (error) {
      if (mounted) showError(context, 'Não foi possível salvar', error);
    }
  }

  Future<void> scoreActions(Score score) async {
    final action = await showAppSheet<String>(
      context,
      builder: (ctx) => AppSheet(
        title: score.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: Text(tr(ctx, 'Renomear')),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.folders),
              title: Text(tr(ctx, 'Coleções')),
              onTap: () => Navigator.pop(ctx, 'organize'),
            ),
            ListTile(
              leading: Icon(
                LucideIcons.trash2,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(tr(ctx, 'Remover da coleção')),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') await rename(score);
    if (action == 'organize') await organize(score);
    if (action == 'remove') await removeScores([score]);
  }

  Future<void> removeScores(List<Score> scores) async {
    if (scores.isEmpty) return;
    final confirmed = await confirmSheet(
      context,
      title: 'Remover da coleção?',
      message:
          '${scores.map((s) => '“${s.name}”').join(', ')}\n${tr(context, 'O PDF e as anotações são mantidos.')}',
      action: 'Remover',
    );
    if (!confirmed || !mounted) return;
    try {
      final ids = scores.map((s) => s.id).toSet();
      await Store.instance.removeFromCollection(widget.collection.id, ids);
      widget.selection.replace(selected.difference(ids));
      if (mounted) {
        removing = false;
        refresh();
      }
    } catch (error) {
      if (mounted) showError(context, 'Não foi possível remover', error);
    }
  }

  void addFromLibrary() => Navigator.pop(context);
  void openSelected() => widget.onOpenSelection != null
      ? widget.onOpenSelection!()
      : openSelectedScores(context, widget.selection);
  void toggleSelection(Score score) => widget.selection.toggle(score.id);

  Widget _sortButton(NotivoColors c) => DesignIcon(
    icon: _sorts[sort].$1,
    label: _sorts[sort].$2,
    onPressed: () {
      sort = (sort + 1) % _sorts.length;
      refresh();
    },
    background: c.soft,
    extent: 48,
    radius: 24,
    size: 20,
  );

  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final width =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).left -
        MediaQuery.paddingOf(context).right;
    final compact = width < 600 || MediaQuery.sizeOf(context).height < 500;
    final gutter = compact ? 20.0 : 40.0;
    return PopScope(
      canPop: !removing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => removing = false);
      },
      child: Scaffold(
        body: SafeArea(
          child: DesignViewport(
            child: FutureBuilder<List<Score>>(
              future: future,
              builder: (context, snap) {
                final scores = snap.data ?? const <Score>[];
                shown = scores;
                final picked = scores
                    .where((s) => selected.contains(s.id))
                    .toList();
                return Stack(
                  children: [
                    CustomScrollView(
                      key: const PageStorageKey('scores'),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            gutter,
                            compact ? 20 : 48,
                            gutter,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 44,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Transform.translate(
                                        offset: const Offset(-10, 0),
                                        child: DesignIcon(
                                          icon: LucideIcons.chevronLeft,
                                          label: tr(context, 'Voltar'),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                        ),
                                      ),
                                      DesignButton(
                                        label: tr(context, 'Importar PDFs'),
                                        onPressed: importFiles,
                                        icon: LucideIcons.plus,
                                        outlined: true,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  widget.collection.name,
                                  style: designText(
                                    compact ? 28 : 36,
                                    c.tx,
                                    height: 1.1,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${scores.length} ${tr(context, 'partituras')}',
                                  style: designText(14, c.tx2),
                                ),
                                const SizedBox(height: 28),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.soft,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              LucideIcons.search,
                                              size: 20,
                                              color: c.tx2,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: TextField(
                                                controller: search,
                                                onChanged: (_) => refresh(),
                                                style: designText(15, c.tx),
                                                decoration:
                                                    InputDecoration.collapsed(
                                                      hintText: tr(
                                                        context,
                                                        'Buscar partituras',
                                                      ),
                                                      hintStyle: designText(
                                                        15,
                                                        c.tx2,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _sortButton(c),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  tr(
                                    context,
                                    'Toque para abrir, no círculo para selecionar. Segure para remover.',
                                  ),
                                  style: designText(13, c.tx2),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                        if (snap.hasError)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                tr(
                                  context,
                                  'Não foi possível abrir as partituras.',
                                ),
                                style: designText(17, c.tx2),
                              ),
                            ),
                          )
                        else if (!snap.hasData)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          )
                        else if (scores.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                tr(context, 'Nenhuma partitura nesta coleção.'),
                                style: designText(17, c.tx2),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: gutter),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                i,
                              ) {
                                final score = scores[i];
                                return ScoreRow(
                                  name: score.name,
                                  collections: score.collections.join(' · '),
                                  selected: selected.contains(score.id),
                                  onSelect: () => toggleSelection(score),
                                  onMenu: () => scoreActions(score),
                                  onTap: removing ||
                                          widget.onOpenSelection != null
                                      ? () => toggleSelection(score)
                                      : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReaderScreen(
                                              initial: [score],
                                              index: 0,
                                            ),
                                          ),
                                        ),
                                  onLongPress: () {
                                    if (!selected.contains(score.id))
                                      toggleSelection(score);
                                    setState(() => removing = true);
                                  },
                                );
                              }, childCount: scores.length),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: selected.isEmpty ? 24 : 120),
                        ),
                      ],
                    ),
                    if (removing)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SelectionBar(
                          count: picked.length,
                          onClose: () => setState(() => removing = false),
                          onDelete: () => removeScores(picked),
                        ),
                      ),
                    if (selected.isNotEmpty && !removing)
                      Positioned(
                        left: compact ? 12 : 96,
                        right: compact ? 12 : 96,
                        bottom: compact ? 16 : 40,
                        child: SelectionPill(
                          count: selected.length,
                          onClear: widget.selection.clear,
                          onOpen: openSelected,
                          onAdd: addFromLibrary,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initial});
  final String initial;
  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final input = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _save() {
    if (input.text.trim().isNotEmpty) Navigator.pop(context, input.text.trim());
  }

  @override
  Widget build(BuildContext context) => AppSheet(
    title: tr(context, 'Renomear partitura'),
    child: TextField(
      controller: input,
      autofocus: true,
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(labelText: tr(context, 'Nome no Notivo')),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Cancelar')),
      ),
      FilledButton(onPressed: _save, child: Text(tr(context, 'Concluir'))),
    ],
  );
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.initial, required this.index});
  final List<Score> initial;
  final int index;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final tabs = [...widget.initial];
  late int active = widget.index.clamp(0, widget.initial.length - 1).toInt();
  final pads = <String, GlobalKey<_AnnotationPadState>>{};
  String tool = 'navigate';
  Color color = noteColors.first;
  bool controlsHidden = false;
  bool exporting = false;
  // Locked: tabs can't be closed and leaving asks for confirmation.
  bool locked = false;

  Future<void> leave({bool home = true}) async {
    if (locked &&
        !await confirmSheet(
          context,
          title: 'Partituras bloqueadas',
          message: tr(context, 'Deseja sair mesmo assim?'),
          action: 'Sair',
        )) {
      return;
    }
    if (!await flushAnnotations() || !mounted) return;
    home
        ? Navigator.popUntil(context, (route) => route.isFirst)
        : Navigator.pop(context);
  }

  Future<bool> flushAnnotations() async {
    try {
      for (final pad in pads.values.toList()) {
        await pad.currentState?.flush();
      }
      return true;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr(context, 'Falha ao salvar anotações')}: $error',
            ),
          ),
        );
      return false;
    }
  }

  Future<void> addTab() async {
    if (!await flushAnnotations()) return;
    if (!mounted) return;
    final scores = await Navigator.push<List<Score>>(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryScreen(
          picking: true,
          initialSelection: tabs.map((score) => score.id).toList(),
        ),
      ),
    );
    if (scores == null || !mounted) return;
    setState(() {
      int? added;
      for (final score in scores) {
        if (!tabs.any((tab) => tab.id == score.id)) {
          tabs.add(score);
          added = tabs.length - 1;
        }
      }
      if (added != null) active = added;
    });
  }

  Future<void> closeTab(int index) async {
    if (locked) return;
    final score = tabs[index];
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (ctx) => AppSheet(
        title: tr(ctx, 'Fechar partitura?'),
        child: Text(
          '${score.name}\n${tr(ctx, 'As anotações serão mantidas.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(ctx, 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(ctx, 'Fechar')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!await flushAnnotations()) return;
    if (!mounted) return;
    final currentIndex = tabs.indexWhere((tab) => tab.id == score.id);
    if (currentIndex < 0) return;
    if (tabs.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      tabs.removeAt(currentIndex);
      pads.removeWhere((key, _) => key.startsWith('${score.id}:'));
      if (currentIndex < active) active--;
      if (active >= tabs.length) active = tabs.length - 1;
    });
  }

  Future<void> _customColor() async {
    final picked = await showAppSheet<Color>(
      context,
      builder: (_) => ColorPickerSheet(initial: color),
    );
    if (picked != null && mounted) setState(() => color = picked);
  }

  Future<void> _undo() async {
    final pages =
        pads.entries
            .where((entry) => entry.key.startsWith('${tabs[active].id}:'))
            .map((entry) => entry.value.currentState)
            .whereType<_AnnotationPadState>()
            .toList()
          ..sort(
            (a, b) => (b.lastEdited ?? DateTime(0)).compareTo(
              a.lastEdited ?? DateTime(0),
            ),
          );
    if (pages.isNotEmpty) await pages.first.undo();
  }

  Future<void> _export(Score score) async {
    setState(() => exporting = true);
    PdfDocument? document;
    try {
      if (!await flushAnnotations()) return;
      document = await PdfDocument.openFile(score.path);
      final exported = pw.Document();
      for (final page in document.pages) {
        // shortcut: export is rasterized at up to 144 dpi, switch to vector marks for editable output.
        final double scale = math
            .min(2.0, math.min(2000 / page.width, 6000 / page.height))
            .toDouble();
        final rendered = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
        );
        if (rendered == null) {
          throw StateError(
            'Não foi possível renderizar a página ${page.pageNumber}.',
          );
        }
        final raster = img.Image.fromBytes(
          width: rendered.width,
          height: rendered.height,
          bytes: rendered.pixels.buffer,
          order: img.ChannelOrder.bgra,
        );
        for (final stroke in await Store.instance.annotations(
          score.id,
          page.pageNumber,
        )) {
          final points = (stroke['points'] as List)
              .cast<Map<String, dynamic>>();
          final argb = stroke['color'] as int;
          final color = img.ColorRgba8(
            (argb >> 16) & 255,
            (argb >> 8) & 255,
            argb & 255,
            stroke['tool'] == 'highlighter' ? 105 : 255,
          );
          if (points.length == 1)
            img.fillCircle(
              raster,
              x: ((points.first['x'] as num) * raster.width).round(),
              y: ((points.first['y'] as num) * raster.height).round(),
              radius: stroke['tool'] == 'highlighter' ? 11 : 2,
              color: color,
            );
          for (var i = 1; i < points.length; i++) {
            img.drawLine(
              raster,
              x1: ((points[i - 1]['x'] as num) * raster.width).round(),
              y1: ((points[i - 1]['y'] as num) * raster.height).round(),
              x2: ((points[i]['x'] as num) * raster.width).round(),
              y2: ((points[i]['y'] as num) * raster.height).round(),
              color: color,
              thickness: stroke['tool'] == 'highlighter' ? 22 : 4,
            );
          }
        }
        final bytes = Uint8List.fromList(img.encodePng(raster));
        rendered.dispose();
        exported.addPage(
          pw.Page(
            pageFormat: pdf.PdfPageFormat(page.width, page.height),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
          ),
        );
      }
      await document.dispose();
      document = null;
      final directory = await getTemporaryDirectory();
      final name = score.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File(p.join(directory.path, '$name.pdf'));
      await file.writeAsBytes(await exported.save(), flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr(context, 'Falha ao exportar')}: $error'),
          ),
        );
    } finally {
      await document?.dispose();
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = tabs[active];
    final c = NotivoColors(context);
    final width =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).left -
        MediaQuery.paddingOf(context).right;
    final compact = width < 600;
    final toolbarWidth = math.min(640.0, width - 24);
    final compactToolbar = toolbarWidth < 640;
    final toolbarHeight = compactToolbar ? 108.0 : 64.0;
    final headerHeight = 56 + toolbarHeight + 1;
    const handleHeight = 24.0;
    final pageGutter = compact ? 8.0 : 20.0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave(home: false);
      },
      child: Scaffold(
      body: SafeArea(
        child: DesignViewport(
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: c.soft)),
              Positioned(
                top: controlsHidden ? handleHeight + 6 : headerHeight,
                left: pageGutter,
                right: pageGutter,
                bottom: 0,
                child: PdfViewer.file(
                  score.path,
                  key: ValueKey(score.id),
                  params: PdfViewerParams(
                    margin: 0,
                    panEnabled: tool == 'navigate',
                    scaleEnabled: tool == 'navigate',
                    underflowAnchor: PdfPageAnchor.top,
                    backgroundColor: c.soft,
                    pageDropShadow: BoxShadow(
                      color: const Color(0xff2e1a6b).withValues(alpha: .12),
                      offset: const Offset(0, 2),
                      blurRadius: 20,
                    ),
                    pageOverlaysBuilder: (context, _, page) {
                      final key = pads.putIfAbsent(
                        '${score.id}:${page.pageNumber}',
                        () => GlobalKey<_AnnotationPadState>(),
                      );
                      return [
                        AnnotationPad(
                          key: key,
                          scoreId: score.id,
                          page: page.pageNumber,
                          tool: tool,
                          color: color,
                        ),
                      ];
                    },
                  ),
                ),
              ),
              if (!controlsHidden)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: headerHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.bg,
                      border: Border(bottom: BorderSide(color: c.line)),
                    ),
                    child: Column(
                      children: [
                  SizedBox(
                    height: 56,
                    child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12),
                    child: Row(
                      spacing: 4,
                      children: [
                        DesignIcon(
                          icon: LucideIcons.house,
                          label: tr(context, 'Início'),
                          size: 20,
                          onPressed: leave,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              spacing: 4,
                              children: [
                                for (var i = 0; i < tabs.length; i++)
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => setState(() => active = i),
                                      child: Container(
                                        height: 56,
                                        padding: EdgeInsets.fromLTRB(
                                          14,
                                          0,
                                          locked ? 14 : 4,
                                          0,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: active == i
                                                  ? c.accent
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          spacing: 6,
                                          children: [
                                            Text(
                                              tabs[i].name,
                                              style: designText(
                                                14,
                                                active == i ? c.tx : c.tx2,
                                                weight: active == i
                                                    ? FontWeight.w500
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                            if (!locked)
                                            DesignIcon(
                                              icon: LucideIcons.x,
                                              label: tr(context, 'Fechar aba'),
                                              onPressed: () => closeTab(i),
                                              extent: compact ? 44 : 28,
                                              radius: 8,
                                              size: 14,
                                              color: active == i ? c.tx : c.tx2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DesignIcon(
                          icon: LucideIcons.plus,
                          label: tr(context, 'Abrir outra partitura'),
                          onPressed: addTab,
                          color: c.tx2,
                          size: 20,
                        ),
                        DesignIcon(
                          icon: locked ? LucideIcons.lock : LucideIcons.lockOpen,
                          label: locked
                              ? 'Desbloquear partituras'
                              : 'Bloquear partituras',
                          onPressed: () => setState(() => locked = !locked),
                          color: locked ? c.accent : c.tx2,
                          background: locked ? c.active : null,
                          size: 20,
                        ),
                        DesignIcon(
                          icon: LucideIcons.chevronUp,
                          label: tr(context, 'Recolher abas e ferramentas'),
                          onPressed: () =>
                              setState(() => controlsHidden = true),
                          color: c.tx2,
                          size: 18,
                        ),
                      ],
                    ),
                    ),
                  ),
                  SizedBox(
                    height: toolbarHeight,
                    child: Center(
                      child: SizedBox(
                        width: toolbarWidth,
                        child: ReaderToolbar(
                          tool: tool,
                          color: color,
                          colors: noteColors,
                          onTool: (value) => setState(() => tool = value),
                          onColor: (value) => setState(() => color = value),
                          onCustom: _customColor,
                          onUndo: _undo,
                          onExport: () => _export(score),
                          exporting: exporting,
                        ),
                      ),
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
              if (controlsHidden)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DesignPill(
                      radius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                      child: SizedBox(
                        width: 64,
                        height: handleHeight,
                        child: DesignIcon(
                          icon: LucideIcons.chevronDown,
                          label: tr(context, 'Mostrar abas e ferramentas'),
                          onPressed: () =>
                              setState(() => controlsHidden = false),
                          extent: handleHeight,
                          radius: 12,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class AnnotationPad extends StatefulWidget {
  const AnnotationPad({
    super.key,
    required this.scoreId,
    required this.page,
    required this.tool,
    required this.color,
  });
  final int scoreId;
  final int page;
  final String tool;
  final Color color;

  @override
  State<AnnotationPad> createState() => _AnnotationPadState();
}

class _AnnotationPadState extends State<AnnotationPad> {
  List<Map<String, dynamic>> strokes = [];
  List<List<Map<String, dynamic>>> undoStack = [];
  Map<String, dynamic>? current;
  DateTime? lastEdited;
  bool ready = false;
  int? pointer;
  Future<void> pendingSave = Future.value();

  @override
  void initState() {
    super.initState();
    _loadAnnotations();
  }

  Future<void> _loadAnnotations() async {
    try {
      final saved = await Store.instance.annotations(
        widget.scoreId,
        widget.page,
      );
      final history = await Store.instance.history(widget.scoreId, widget.page);
      final edited = await Store.instance.lastAnnotationEdit(
        widget.scoreId,
        widget.page,
      );
      if (mounted)
        setState(() {
          strokes = saved;
          undoStack = history;
          lastEdited = edited;
          ready = true;
        });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr(context, 'Falha ao carregar anotações')}: $error',
            ),
          ),
        );
    }
  }

  List<Map<String, dynamic>> _copyStrokes() => strokes
      .map(
        (stroke) => {
          'tool': stroke['tool'],
          'color': stroke['color'],
          'points': (stroke['points'] as List)
              .map((point) => Map<String, dynamic>.from(point as Map))
              .toList(),
        },
      )
      .toList();

  Map<String, double> _point(Offset offset, Size size) => {
    'x': (offset.dx / size.width).clamp(0.0, 1.0),
    'y': (offset.dy / size.height).clamp(0.0, 1.0),
  };

  void _start(Offset position, Size size) {
    undoStack.add(_copyStrokes());
    if (widget.tool == 'eraser') {
      _erase(position, size);
    } else {
      current = {
        'tool': widget.tool,
        'color': widget.color.toARGB32(),
        'points': [_point(position, size)],
      };
      setState(() {});
    }
  }

  void _move(Offset position, Size size) {
    if (widget.tool == 'eraser') {
      _erase(position, size);
    } else if (current != null) {
      (current!['points'] as List).add(_point(position, size));
      setState(() {});
    }
  }

  void _erase(Offset offset, Size size) {
    final point = _point(offset, size);
    strokes.removeWhere((stroke) {
      final points = stroke['points'] as List;
      Offset pixel(dynamic item) => Offset(
        (item['x'] as num) * size.width,
        (item['y'] as num) * size.height,
      );
      final target = Offset(
        point['x']! * size.width,
        point['y']! * size.height,
      );
      for (var i = 0; i < points.length; i++) {
        final start = pixel(points[i]);
        final end = pixel(points[math.min(i + 1, points.length - 1)]);
        final segment = end - start;
        final t = segment.distanceSquared == 0
            ? 0.0
            : (((target - start).dx * segment.dx +
                          (target - start).dy * segment.dy) /
                      segment.distanceSquared)
                  .clamp(0.0, 1.0);
        if ((target - (start + segment * t)).distanceSquared < 400) return true;
      }
      return false;
    });
    setState(() {});
  }

  Future<void> _commit() async {
    if (current != null) strokes.add(current!);
    current = null;
    lastEdited = DateTime.now();
    if (mounted) setState(() {});
    final data = _copyStrokes();
    final history = List<List<Map<String, dynamic>>>.from(undoStack);
    final edited = lastEdited!;
    pendingSave = pendingSave
        .catchError((Object _) {})
        .then(
          (_) => Store.instance.saveAnnotations(
            widget.scoreId,
            widget.page,
            data,
            history,
            edited,
          ),
        );
    try {
      await pendingSave;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr(context, 'Falha ao salvar anotações')}: $error',
            ),
          ),
        );
    }
  }

  Future<void> flush() async {
    if (pointer != null) {
      pointer = null;
      await _commit();
    }
    await pendingSave;
  }

  Future<void> undo() async {
    if (undoStack.isEmpty) return;
    setState(() => strokes = undoStack.removeLast());
    await _commit();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !ready || widget.tool == 'navigate',
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (pointer != null || event.buttons != kPrimaryButton) return;
        pointer = event.pointer;
        _start(event.localPosition, context.size!);
      },
      onPointerMove: (event) {
        if (event.pointer == pointer) _move(event.localPosition, context.size!);
      },
      onPointerUp: (event) {
        if (event.pointer != pointer) return;
        pointer = null;
        _commit();
      },
      onPointerCancel: (event) {
        if (event.pointer != pointer) return;
        pointer = null;
        current = null;
        if (undoStack.isNotEmpty) strokes = undoStack.removeLast();
        setState(() {});
      },
      child: CustomPaint(
        painter: _StrokePainter([...strokes, if (current != null) current!]),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.strokes);
  final List<Map<String, dynamic>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final points = (stroke['points'] as List).cast<Map<String, dynamic>>();
      if (points.isEmpty) continue;
      final highlight = stroke['tool'] == 'highlighter';
      final paint = Paint()
        ..color = Color(stroke['color'] as int)
            .withValues(alpha: highlight ? .32 : 1)
        ..strokeWidth = highlight ? 18 : 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(
          (points.first['x'] as num) * size.width,
          (points.first['y'] as num) * size.height,
        );
      if (points.length == 1) {
        canvas.drawCircle(
          Offset(
            (points.first['x'] as num) * size.width,
            (points.first['y'] as num) * size.height,
          ),
          paint.strokeWidth / 2,
          Paint()..color = paint.color,
        );
        continue;
      }
      for (final point in points.skip(1)) {
        path.lineTo(
          (point['x'] as num) * size.width,
          (point['y'] as num) * size.height,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
