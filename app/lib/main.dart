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

import 'package:archive/archive_io.dart'
    show
        ArchiveFile,
        InputFileStream,
        OutputFileStream,
        ZipDecoder,
        ZipFileEncoder;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
// shortcut: copied from pubspec.yaml by hand, use package_info_plus if it starts drifting.
const appVersion = '1.0.0';
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
      version: 4,
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE scores ADD COLUMN opened_at TEXT');
        }
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
          'CREATE TABLE scores(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,original_name TEXT NOT NULL,path TEXT NOT NULL UNIQUE,imported_at TEXT NOT NULL,opened_at TEXT)',
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
        const seeds = [('Minhas partituras', '#6D3BD2', 'music')];
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
    // Also clears scores orphaned before removal started deleting them.
    await _purgeOrphans(db);
    return db;
  }

  /// Scores left in no collection are deleted with their annotations and copied PDF.
  /// The file the user picked on import is never touched.
  Future<void> _purgeOrphans(Database db) async {
    final rows = await db.rawQuery(
      'SELECT id,path FROM scores WHERE id NOT IN (SELECT score_id FROM collection_scores)',
    );
    if (rows.isEmpty) return;
    await db.transaction((txn) async {
      for (final row in rows) {
        await txn.delete(
          'annotations',
          where: 'score_id=?',
          whereArgs: [row['id']],
        );
        await txn.delete('scores', where: 'id=?', whereArgs: [row['id']]);
      }
    });
    for (final row in rows) {
      final file = File(row['path']! as String);
      if (await file.exists()) await file.delete();
    }
  }

  /// How many of [scoreIds] (every score when null) would be in no collection
  /// once unlinked from [collectionIds], and so get deleted.
  Future<int> orphanedBy(
    Iterable<int> collectionIds, [
    Iterable<int>? scoreIds,
  ]) async {
    final ids = collectionIds.join(',');
    final rows = await (await _db).rawQuery('''
      SELECT COUNT(*) AS n FROM scores s
      WHERE EXISTS (SELECT 1 FROM collection_scores WHERE score_id=s.id AND collection_id IN ($ids))
      AND NOT EXISTS (SELECT 1 FROM collection_scores WHERE score_id=s.id AND collection_id NOT IN ($ids))
      ${scoreIds == null ? '' : 'AND s.id IN (${scoreIds.join(',')})'}
    ''');
    return rows.first['n']! as int;
  }

  /// Zips every score PDF with the library rows into one shareable file.
  Future<File> exportBackup() async {
    final db = await _db;
    final scores = await db.query('scores');
    final data = {
      'notivo_backup': 1,
      'collections': await db.query('collections'),
      'scores': [
        for (final s in scores)
          {...s, 'path': p.basename(s['path']! as String)},
      ],
      'collection_scores': await db.query('collection_scores'),
      'annotations': await db.query('annotations'),
    };
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final zip = File(
      p.join((await getTemporaryDirectory()).path, 'notivo-backup-$day.zip'),
    );
    final encoder = ZipFileEncoder()..create(zip.path);
    try {
      encoder.addArchiveFile(
        ArchiveFile.string('notivo-backup.json', jsonEncode(data)),
      );
      for (final s in scores) {
        final path = s['path']! as String;
        await encoder.addFile(File(path), 'pdfs/${p.basename(path)}');
      }
    } finally {
      await encoder.close();
    }
    return zip;
  }

  /// Replaces the whole library (not the preferences) with an [exportBackup] file.
  Future<void> restoreBackup(String zipPath) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final json = archive.findFile('notivo-backup.json')?.readBytes();
      if (json == null) throw const FormatException('Sem notivo-backup.json');
      final data = jsonDecode(utf8.decode(json)) as Map<String, dynamic>;
      if (data['notivo_backup'] != 1) {
        throw const FormatException('Versão de backup desconhecida');
      }
      List<Map<String, Object?>> rows(String key) =>
          (data[key] as List).cast<Map<String, Object?>>();
      final dir = (await getApplicationSupportDirectory()).path;
      final db = await _db;
      final old = {
        for (final r in await db.query('scores', columns: ['path']))
          r['path']! as String,
      };
      // Only the bare file name is kept, so a crafted backup can't write outside the app folder.
      final scores = [
        for (final s in rows('scores'))
          {...s, 'path': p.join(dir, p.basename(s['path']! as String))},
      ];
      final written = <String>[];
      try {
        for (final s in scores) {
          final target = s['path']! as String;
          final entry = archive.findFile('pdfs/${p.basename(target)}');
          if (entry == null || !entry.isFile) {
            throw FormatException('Sem o PDF de ${s['name']}');
          }
          final out = OutputFileStream(target);
          try {
            entry.writeContent(out);
          } finally {
            await out.close();
          }
          written.add(target);
        }
        await db.transaction((txn) async {
          for (final table in [
            'annotations',
            'collection_scores',
            'scores',
            'collections',
          ]) {
            await txn.delete(table);
          }
          for (final r in rows('collections'))
            await txn.insert('collections', r);
          for (final r in scores) await txn.insert('scores', r);
          for (final r in rows('collection_scores')) {
            await txn.insert('collection_scores', r);
          }
          for (final r in rows('annotations'))
            await txn.insert('annotations', r);
        });
      } catch (_) {
        for (final path in written) {
          if (!old.contains(path)) await File(path).delete();
        }
        rethrow;
      }
      final kept = scores.map((s) => s['path']).toSet();
      for (final path in old) {
        if (!kept.contains(path) && await File(path).exists()) {
          await File(path).delete();
        }
      }
    } finally {
      await input.close();
    }
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
    final db = await _db;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete(
          'collection_scores',
          where: 'collection_id=?',
          whereArgs: [id],
        );
        await txn.delete('collections', where: 'id=?', whereArgs: [id]);
      }
    });
    await _purgeOrphans(db);
  }

  /// With [purge] false, scores left in no collection survive until
  /// [purgeOrphans] (or the next launch), so the removal can still be undone.
  Future<void> removeFromCollection(
    int collectionId,
    Iterable<int> scoreIds, {
    bool purge = true,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final id in scoreIds) {
        await txn.delete(
          'collection_scores',
          where: 'collection_id=? AND score_id=?',
          whereArgs: [collectionId, id],
        );
      }
    });
    if (purge) await _purgeOrphans(db);
  }

  Future<void> purgeOrphans() async => _purgeOrphans(await _db);

  Future<void> addToCollections(
    Iterable<int> scoreIds,
    Iterable<int> collectionIds,
  ) async {
    await (await _db).transaction((txn) async {
      for (final scoreId in scoreIds) {
        for (final collectionId in collectionIds) {
          await txn.insert('collection_scores', {
            'collection_id': collectionId,
            'score_id': scoreId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
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
    list.sort((a, b) {
      final r = recent
          ? (b['imported_at']! as String).compareTo(a['imported_at']! as String)
          : naturalCompare(a['name']! as String, b['name']! as String);
      return reverse ? -r : r;
    });
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

  /// Copies the PDF at [sourcePath] into the app and links it to [collectionId].
  Future<void> importPdf(
    String? sourcePath,
    String name,
    int? collectionId,
  ) async {
    if (sourcePath == null || !name.toLowerCase().endsWith('.pdf')) {
      throw FormatException('$name não é um PDF.');
    }
    final source = File(sourcePath);
    final handle = await source.open();
    late final String header;
    try {
      header = latin1.decode(await handle.read(1024), allowInvalid: true);
    } finally {
      await handle.close();
    }
    if (!header.contains('%PDF-')) {
      throw FormatException('$name não contém um PDF válido.');
    }
    final dir = await getApplicationSupportDirectory();
    final id = DateTime.now().microsecondsSinceEpoch;
    final target = File(p.join(dir.path, '$id.pdf'));
    try {
      await source.copy(target.path);
      final db = await _db;
      await db.transaction((txn) async {
        final scoreId = await txn.insert('scores', {
          'name': p.basenameWithoutExtension(name),
          'original_name': name,
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

  /// Remembers when scores were last opened, for the home screen.
  Future<void> markOpened(Iterable<int> ids) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    for (final id in ids) {
      await db.update(
        'scores',
        {'opened_at': now},
        where: 'id=?',
        whereArgs: [id],
      );
    }
  }

  /// The [limit] most recently opened scores, newest first.
  Future<List<Score>> recentScores([int limit = 4]) async {
    final rows = await (await _db).query(
      'scores',
      columns: ['id'],
      where: 'opened_at IS NOT NULL',
      orderBy: 'opened_at DESC',
      limit: limit,
    );
    final all = {for (final s in await scores()) s.id: s};
    return [for (final r in rows) ?all[r['id']]];
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

  Future<void> setScoreCollections(
    int scoreId,
    Set<int> collectionIds, {
    bool purge = true,
  }) async {
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
    if (purge) await _purgeOrphans(db);
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every crash and handled error goes to a small log the user can send us.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logError(details.exception, details.stack);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    logError(error, stack);
    return true;
  };
  await pdfrxFlutterInitialize();
  runApp(const NotivoApp());
}

/// The error log in the app folder, attached to "Enviar feedback".
Future<File> errorLogFile() async =>
    File(p.join((await getApplicationSupportDirectory()).path, 'errors.log'));

/// Appends [error] to the log, keeping only the newest 64 KB.
Future<void> logError(Object error, [StackTrace? stack]) async {
  try {
    final file = await errorLogFile();
    final entry =
        '${DateTime.now().toIso8601String()} $error\n${stack ?? ''}\n';
    var text = (await file.exists()) ? await file.readAsString() : '';
    text += entry;
    if (text.length > 64 * 1024) text = text.substring(text.length - 48 * 1024);
    await file.writeAsString(text, flush: true);
  } catch (_) {
    // Logging must never become the next error.
  }
}

class NotivoApp extends StatefulWidget {
  const NotivoApp({super.key});
  @override
  State<NotivoApp> createState() => _NotivoAppState();
}

/// System, light or dark; Settings writes it, the app follows it.
final themeMode = ValueNotifier(ThemeMode.system);

void setThemeMode(ThemeMode mode) {
  themeMode.value = mode;
  Store.instance.setPreference('theme', mode.name);
}

class _NotivoAppState extends State<NotivoApp> {
  String? language;
  @override
  void initState() {
    super.initState();
    Store.instance.preference('theme').then((value) {
      for (final mode in ThemeMode.values) {
        if (mode.name == value) themeMode.value = mode;
      }
    });
    Store.instance.preference('language').then((value) {
      if (mounted && (value == 'pt' || value == 'en'))
        setState(() => language = value!);
    });
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
          error: dark ? const Color(0xffffb4ab) : const Color(0xffc62828),
        );
    // Sheet and dialog buttons: 48 px tall pills, bold label.
    final pill = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      useMaterial3: true,
      fontFamily: 'Inter',
      // Soft violet press highlight everywhere, no ripple.
      splashFactory: NoSplash.splashFactory,
      highlightColor: scheme.primary.withValues(alpha: dark ? .16 : .10),
      hoverColor: scheme.primary.withValues(alpha: .06),
      dividerColor: scheme.outlineVariant,
      filledButtonTheme: FilledButtonThemeData(style: pill),
      textButtonTheme: TextButtonThemeData(style: pill),
      bottomSheetTheme: BottomSheetThemeData(
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(32, 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: themeMode,
    builder: (context, mode, _) => MaterialApp(
      title: 'Notivo',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: mode,
      locale: language == null ? null : Locale(language!),
      supportedLocales: notivoSupportedLocales,
      localizationsDelegates: notivoLocalizationDelegates,
      home: LibraryScreen(onLanguage: changeLanguage),
    ),
  );
}

/// Shows a plain-language message; the technical error only goes to the log.
/// Why [error] happened, in plain Portuguese (pass it through [tr] to show it).
String errorReason(Object error) => switch (error) {
  PdfPasswordException() => 'O PDF está protegido por senha.',
  PdfException() ||
  FormatException() => 'O arquivo não é válido ou está corrompido.',
  FileSystemException(osError: OSError(errorCode: 28)) =>
    'Sem espaço livre no aparelho.',
  FileSystemException(osError: OSError(errorCode: 1 || 13)) =>
    'Sem permissão para acessar o arquivo.',
  FileSystemException(osError: OSError(errorCode: 2)) =>
    'O arquivo não foi encontrado.',
  FileSystemException() => 'Não foi possível ler ou gravar o arquivo.',
  DatabaseException() => 'Falha ao gravar na biblioteca do app.',
  PlatformException() => 'O Android não permitiu a operação.',
  _ => 'Erro inesperado; ele fica no registro enviado em “Enviar feedback”.',
};

void showError(BuildContext context, String message, Object error) {
  debugPrint('$message: $error');
  logError('$message: $error');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      content: Text(
        '${tr(context, message)}. ${tr(context, errorReason(error))}',
      ),
    ),
  );
}

/// Covers the screen with a spinner and [label] while [task] runs; the task
/// can change the label through the notifier it receives (e.g. "2 de 5").
Future<T> withLoading<T>(
  BuildContext context,
  String label,
  Future<T> Function(ValueNotifier<String> status) task,
) async {
  final status = ValueNotifier(label);
  final c = NotivoColors(context);
  final entry = OverlayEntry(
    builder: (_) => Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black38),
        Center(
          child: Material(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: ValueListenableBuilder(
                      valueListenable: status,
                      builder: (_, text, _) => Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: designText(16, c.tx, weight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    return await task(status);
  } finally {
    entry.remove();
    status.dispose();
  }
}

/// Snack bar with "Desfazer"; completes with how it closed.
Future<SnackBarClosedReason> showUndo(
  BuildContext context,
  String message,
  VoidCallback onUndo,
) {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return messenger
      .showSnackBar(
        SnackBar(
          content: Text(message),
          persist: false,
          action: SnackBarAction(
            label: tr(context, 'Desfazer'),
            onPressed: onUndo,
          ),
        ),
      )
      .closed;
}

/// After a deletion was confirmed: Undo puts the links back; otherwise,
/// once the bar closes, the scores and their annotations are deleted.
void offerUndoDeletion(
  BuildContext context,
  int count,
  Future<void> Function() restore,
) {
  var undone = false;
  showUndo(
    context,
    plural(context, count, 'partitura apagada', 'partituras apagadas'),
    () async {
      undone = true;
      try {
        await restore();
      } catch (error) {
        if (context.mounted)
          showError(context, 'Não foi possível desfazer', error);
      }
    },
  ).then((_) {
    if (!undone) Store.instance.purgeOrphans();
  });
}

/// Picks PDFs and imports each into [collectionId]; one bad file doesn't stop the rest.
/// Returns how many were imported.
/// Imports [files] (path and name), or the PDFs the user picks when null.
Future<int> importPdfs(
  BuildContext context,
  int collectionId, {
  List<({String? path, String name})>? files,
}) async {
  final picked =
      files ??
      [
        for (final file in await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        ))
          (path: file.path, name: file.name),
      ];
  if (picked.isEmpty || !context.mounted) return 0;
  // File name and the reason it failed, shown together at the end.
  final failed = <(String, String)>[];
  var added = 0;
  final importing = tr(context, 'Importando');
  final of = tr(context, 'de');
  await withLoading(context, importing, (status) async {
    for (var i = 0; i < picked.length; i++) {
      final file = picked[i];
      status.value = picked.length == 1
          ? '$importing ${file.name}'
          : '$importing ${i + 1} $of ${picked.length}';
      try {
        await Store.instance.importPdf(file.path, file.name, collectionId);
        added++;
      } catch (error) {
        logError('Import ${file.name}: $error');
        failed.add((file.name, errorReason(error)));
      }
    }
  });
  if (!context.mounted) return added;
  if (failed.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$added ${tr(context, added == 1 ? 'partitura importada' : 'partituras importadas')}',
        ),
      ),
    );
    return added;
  }
  final c = NotivoColors(context);
  await showAppSheet<void>(
    context,
    builder: (ctx) => AppSheet(
      title: tr(ctx, 'Não foi possível importar'),
      subtitle: added == 0
          ? plural(ctx, failed.length, 'arquivo com erro', 'arquivos com erro')
          : '${plural(ctx, added, 'partitura importada', 'partituras importadas')} · ${plural(ctx, failed.length, 'arquivo com erro', 'arquivos com erro')}',
      actions: [
        SheetPrimary(tr(ctx, 'Entendi'), onPressed: () => Navigator.pop(ctx)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          for (final (name, reason) in failed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: designText(15, c.tx, weight: FontWeight.w600),
                ),
                Text(tr(ctx, reason), style: designText(14, c.tx2)),
              ],
            ),
        ],
      ),
    ),
  );
  return added;
}

/// Sheet with a checkbox per collection; returns the chosen ids, or null on cancel.
/// [action] names the primary button from how many are checked.
Future<Set<int>?> pickCollections(
  BuildContext context, {
  required String title,
  required String Function(int count) action,
  String? subtitle,
  Set<int> initial = const {},
}) async {
  final all = await Store.instance.collections();
  if (!context.mounted) return null;
  final chosen = {...initial};
  var query = '';
  return showAppSheet<Set<int>>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => AppSheet(
        title: tr(ctx, title),
        subtitle: subtitle,
        list: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Long lists get a filter, as the sheet standard asks.
            if (all.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SearchField(
                  hint: tr(ctx, 'Buscar coleção'),
                  onChanged: (value) => setSheet(() => query = fold(value)),
                ),
              ),
            for (final collection in all)
              if (fold(collection.name).contains(query))
                CheckboxListTile(
                  value: chosen.contains(collection.id),
                  secondary: CircleAvatar(
                    radius: 16,
                    backgroundColor: _color(collection.color),
                  ),
                  title: Text(collection.name),
                  onChanged: (value) => setSheet(
                    () => value == true
                        ? chosen.add(collection.id)
                        : chosen.remove(collection.id),
                  ),
                ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(ctx, 'Cancelar')),
          ),
          SheetPrimary(
            action(chosen.length),
            onPressed: () => Navigator.pop(ctx, chosen),
          ),
        ],
      ),
    ),
  );
}

/// "1 coleção", "3 coleções": the count with the noun in the right number.
String plural(BuildContext context, int count, String one, String many) =>
    '$count ${tr(context, count == 1 ? one : many)}';

/// Explains that [count] scores in no other collection will be deleted.
String deletionNotice(BuildContext context, int count) => count == 0
    ? tr(context, 'As partituras continuam nas outras coleções.')
    : '$count ${tr(context, count == 1 ? 'partitura não está em outra coleção e será apagada do Notivo, com suas anotações.' : 'partituras não estão em outra coleção e serão apagadas do Notivo, com suas anotações.')} ${tr(context, 'O PDF original continua no aparelho.')}';

Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = true,
}) async =>
    await showAppSheet<bool>(
      context,
      builder: (ctx) => AppSheet(
        title: tr(ctx, title),
        child: Text(message, style: designText(15, NotivoColors(ctx).tx)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(ctx, 'Cancelar')),
          ),
          SheetPrimary(
            tr(ctx, action),
            destructive: destructive,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    ) ==
    true;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    this.onLanguage,
    this.picking = false,
    this.initialSelection = const [],
  });
  final ValueChanged<String>? onLanguage;
  final bool picking;
  final List<int> initialSelection;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Future<List<Collection>>? future;
  Future<List<Score>>? recents;
  final selection = ScoreSelection();
  final search = TextEditingController();
  // "Ver todas": lists every score even with an empty search.
  bool showAll = false;
  // Collections picked by long press, for removal.
  Set<int> picked = {};
  void refresh() => setState(() {
    future = Store.instance.collections();
    recents = Store.instance.recentScores();
  });
  void selectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    future = Store.instance.collections();
    recents = Store.instance.recentScores();
    selection.replace(widget.initialSelection);
    if (!widget.picking) {
      // A PDF that started the app, then any sent while it runs.
      incoming.setMethodCallHandler((call) async {
        if (call.method == 'opened') receive(call.arguments as String?);
      });
      incoming.invokeMethod<String>('take').then(receive);
    }
    selection.addListener(selectionChanged);
  }

  @override
  void dispose() {
    selection.removeListener(selectionChanged);
    selection.dispose();
    search.dispose();
    super.dispose();
  }

  /// Picking for the reader: a recent score opens its collection with it
  /// already checked. Otherwise it opens like any score.
  static const incoming = MethodChannel('notivo/incoming');

  /// A PDF received from another app: choose the collection and import it.
  Future<void> receive(String? path) async {
    if (path == null || !mounted) return;
    await importHere([(path: path, name: p.basename(path))]);
    // The copy in the cache is no longer needed once imported (or declined).
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> openRecent(Score score) async {
    if (!widget.picking) return openScore(score);
    final all = await future ?? const <Collection>[];
    final home = all
        .where((c) => score.collectionIds.contains(c.id))
        .firstOrNull;
    if (!selection.value.contains(score.id)) selection.toggle(score.id);
    if (home != null && mounted) await openCollection(home);
  }

  Future<void> openScore(Score score) async {
    if (widget.picking || selection.value.isNotEmpty) {
      return selection.toggle(score.id);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(initial: [score], index: 0),
      ),
    );
    if (mounted) refresh();
  }

  /// Search results, or every score after "Ver todas".
  Widget _results(NotivoColors c) => FutureBuilder<List<Score>>(
    future: Store.instance.scores(search: search.text),
    builder: (context, snap) {
      final scores = snap.data ?? const <Score>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  search.text.trim().isEmpty
                      ? tr(context, 'Todas as partituras')
                      : plural(
                          context,
                          scores.length,
                          'resultado',
                          'resultados',
                        ),
                  style: designText(18, c.tx, weight: FontWeight.w600),
                ),
              ),
              DesignIcon(
                icon: LucideIcons.x,
                label: 'Fechar',
                radius: 22,
                onPressed: () => setState(() {
                  showAll = false;
                  search.clear();
                  FocusScope.of(context).unfocus();
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (snap.hasData && scores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                tr(context, 'Nenhuma partitura encontrada.'),
                style: designText(16, c.tx2),
              ),
            ),
          for (final score in scores)
            ScoreRow(
              name: score.name,
              path: score.path,
              collections: score.collections.join(' · '),
              selected: selection.value.contains(score.id),
              onSelect: () => selection.toggle(score.id),
              onLongPress: () => selection.toggle(score.id),
              onTap: () => openScore(score),
            ),
        ],
      );
    },
  );

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
        builder: (_) => SettingsScreen(onLanguage: widget.onLanguage),
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final side = compact ? 12.0 : math.max(96.0, (width - 640) / 2);
    final searching = showAll || search.text.trim().isNotEmpty;
    return PopScope(
      canPop: picked.isEmpty && !searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          picked = {};
          showAll = false;
          search.clear();
        });
      },
      child: Scaffold(
        body: SafeArea(
          child: DesignViewport(
            child: Stack(
              children: [
                FutureBuilder<List<Collection>>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          tr(context, 'Não foi possível abrir a biblioteca.'),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return FutureBuilder<List<Score>>(
                      future: recents,
                      builder: (context, recent) => LibraryLayout(
                        brand: NotivoWordmark(
                          fontSize: compact ? 28 : 36,
                          color: c.dark ? Colors.white : c.tx,
                          markColor: c.mark,
                        ),
                        onMenu: widget.picking
                            ? () => Navigator.pop(context)
                            : openMenu,
                        picking: widget.picking,
                        onCreate: () => editCollection(),
                        onImport: widget.picking ? null : importHere,
                        bottomPadding: selection.value.isEmpty && picked.isEmpty
                            ? 40
                            : 120,
                        search: SearchField(
                          controller: search,
                          height: compact ? 48 : 52,
                          hint: tr(
                            context,
                            compact
                                ? 'Buscar partituras'
                                : 'Buscar em todas as coleções',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        onSeeAll: () => setState(() => showAll = true),
                        results: searching ? _results(c) : null,
                        recents: [
                          for (final score in recent.data ?? const <Score>[])
                            RecentScoreCard(
                              name: score.name,
                              subtitle: score.collections.join(' · '),
                              path: score.path,
                              onTap: () => openRecent(score),
                            ),
                        ],
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
                      ),
                    );
                  },
                ),
                if (picked.isNotEmpty || selection.value.isNotEmpty)
                  Positioned(
                    left: side,
                    right: side,
                    bottom: compact ? 16 : 40,
                    child: picked.isNotEmpty
                        ? SelectionBar(
                            count: picked.length,
                            onClose: () => setState(() => picked = {}),
                            onDelete: removePicked,
                            deleteLabel: 'Remover coleção',
                          )
                        : SelectionBar(
                            count: selection.value.length,
                            onClose: selection.clear,
                            onOpen: openSelection,
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
          onCollectionActions: widget.picking ? null : collectionActions,
        ),
      ),
    );
    if (mounted) refresh();
  }

  /// Imports from the home screen: asks for the target only when there is a choice.
  /// [files] come from "Abrir com"/"Compartilhar"; without them the file picker opens.
  Future<void> importHere([List<({String? path, String name})>? files]) async {
    var all = await future ?? const <Collection>[];
    if (all.isEmpty) {
      await editCollection();
      all = await Store.instance.collections();
    }
    if (!mounted || all.isEmpty) return;
    final target = all.length == 1
        ? all.first
        : await showAppSheet<Collection>(
            context,
            builder: (ctx) => AppSheet(
              title: tr(ctx, 'Importar para'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final collection in all)
                    ListTile(
                      leading: Icon(collectionIcon(collection.icon)),
                      title: Text(collection.name),
                      onTap: () => Navigator.pop(ctx, collection),
                    ),
                ],
              ),
            ),
          );
    if (target == null || !mounted) return;
    if (await importPdfs(context, target.id, files: files) > 0 && mounted) {
      refresh();
    }
  }

  Future<void> collectionActions(Collection collection) async {
    final action = await showActionSheet<String>(
      context,
      title: collection.name,
      leading: CollectionBadge(collection: collection, size: 44),
      actions: [
        (
          value: 'edit',
          icon: LucideIcons.pencil,
          label: tr(context, 'Editar coleção'),
          destructive: false,
        ),
        (
          value: 'remove',
          icon: LucideIcons.trash2,
          label: tr(context, 'Remover coleção'),
          destructive: true,
        ),
      ],
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
    final lost = await Store.instance.orphanedBy(collections.map((c) => c.id));
    if (!mounted) return;
    final confirmed = await confirmSheet(
      context,
      title: 'Remover coleção?',
      message: '$names\n${deletionNotice(context, lost)}',
      action: 'Remover',
    );
    if (!confirmed || !mounted) return;
    try {
      await Store.instance.deleteCollections(collections.map((c) => c.id));
      final alive = (await Store.instance.scores()).map((s) => s.id).toSet();
      selection.replace(selection.value.where(alive.contains));
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
        title: tr(
          context,
          existing == null ? 'Nova coleção' : 'Editar coleção',
        ),
        action: tr(
          context,
          existing == null ? 'Criar coleção' : 'Salvar coleção',
        ),
        name: existing?.name ?? '',
        icon: existing?.icon ?? 'music',
        color: _color(existing?.color ?? '#6D3BD2'),
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
      if (mounted)
        showError(context, 'Não foi possível salvar a coleção', error);
    }
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onLanguage});
  final ValueChanged<String>? onLanguage;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool busy = false;
  bool paged = true;
  bool penOnly = false;

  @override
  void initState() {
    super.initState();
    Store.instance.preference('reading_mode').then((value) {
      if (mounted) setState(() => paged = value != 'continuous');
    });
    Store.instance.preference('pen_only').then((value) {
      if (mounted) setState(() => penOnly = value == '1');
    });
  }

  /// Opens the share sheet (e-mail, WhatsApp…) with a short report and the error log.
  Future<void> sendFeedback() async {
    try {
      final log = await errorLogFile();
      final text =
          'Notivo $appVersion · Android ${Platform.operatingSystemVersion}\n\n'
          '${tr(context, 'O que aconteceu:')}\n';
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Notivo — feedback',
          text: text,
          files: [if (await log.exists()) XFile(log.path)],
        ),
      );
    } catch (error) {
      if (mounted)
        showError(context, 'Não foi possível abrir o compartilhamento', error);
    }
  }

  Future<void> backup() async {
    setState(() => busy = true);
    try {
      final zip = await withLoading(
        context,
        tr(context, 'Criando backup…'),
        (_) => Store.instance.exportBackup(),
      );
      await SharePlus.instance.share(ShareParams(files: [XFile(zip.path)]));
    } catch (error) {
      if (mounted) showError(context, 'Não foi possível criar o backup', error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null || !mounted) return;
    if (!await confirmSheet(
          context,
          title: 'Restaurar backup?',
          message: tr(
            context,
            'A biblioteca atual será substituída pelas coleções, partituras e anotações do backup.',
          ),
          action: 'Restaurar backup',
          // Replaces the library but deletes nothing outside the backup: violet, not red.
          destructive: false,
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await withLoading(
        context,
        tr(context, 'Restaurando backup…'),
        (_) => Store.instance.restoreBackup(path),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'Backup restaurado'))),
        );
      }
    } catch (error) {
      if (mounted)
        showError(context, 'Não foi possível restaurar o backup', error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _section(String title, List<Widget> rows, NotivoColors c) => Column(
    // Stretch: every card fills the column, whatever its content.
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          tr(context, title),
          style: designText(13, c.tx2, weight: FontWeight.w600),
        ),
      ),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 16, color: c.rowLine),
              rows[i],
            ],
          ],
        ),
      ),
    ],
  );

  Widget _row(
    NotivoColors c, {
    required String title,
    String? subtitle,
    IconData? icon,
    Widget? trailing,
    // Small controls (a switch, a short value) stay on the right even on phones.
    bool inline = false,
    VoidCallback? onTap,
  }) {
    final text = Row(
      spacing: 14,
      children: [
        if (icon != null) Icon(icon, size: 22, color: c.tx),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(context, title),
                style: designText(16, c.tx, weight: FontWeight.w500),
              ),
              if (subtitle != null)
                Text(tr(context, subtitle), style: designText(13, c.tx2)),
            ],
          ),
        ),
      ],
    );
    return InkWell(
      onTap: busy && onTap != null ? null : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          // Text on the left, control on the right; narrow cards put the control below.
          child: LayoutBuilder(
            builder: (context, bounds) => trailing == null
                ? Align(alignment: Alignment.centerLeft, child: text)
                : inline || bounds.maxWidth >= 480
                ? Row(
                    spacing: 12,
                    children: [
                      Expanded(child: text),
                      trailing,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [text, trailing],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final width = MediaQuery.sizeOf(context).width;
    // Control on the right of the text when there is room for both.
    Widget control(Widget child) => width < 600
        ? child
        : Padding(padding: const EdgeInsets.only(left: 16), child: child);
    return Scaffold(
      backgroundColor: c.soft,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, width < 600 ? 16 : 40, 20, 32),
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Transform.translate(
                      offset: const Offset(-10, 0),
                      child: DesignIcon(
                        icon: LucideIcons.chevronLeft,
                        label: 'Voltar',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Text(
                      tr(context, 'Configurações'),
                      style: designText(28, c.tx, weight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _section('Aparência', [
                  _row(
                    c,
                    title: 'Tema',
                    subtitle: 'Sistema segue o modo do aparelho',
                    trailing: control(
                      ValueListenableBuilder(
                        valueListenable: themeMode,
                        builder: (context, mode, _) => Segmented<ThemeMode>(
                          value: mode,
                          onChanged: setThemeMode,
                          segments: const [
                            (
                              value: ThemeMode.system,
                              label: 'Sistema',
                              icon: null,
                            ),
                            (
                              value: ThemeMode.light,
                              label: 'Claro',
                              icon: null,
                            ),
                            (
                              value: ThemeMode.dark,
                              label: 'Escuro',
                              icon: null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _row(
                    c,
                    title: 'Idioma',
                    trailing: control(
                      Segmented<String>(
                        value: Localizations.localeOf(context).languageCode,
                        onChanged: (value) => widget.onLanguage?.call(value),
                        segments: const [
                          (value: 'pt', label: 'Português', icon: null),
                          (value: 'en', label: 'English', icon: null),
                        ],
                      ),
                    ),
                  ),
                ], c),
                const SizedBox(height: 24),
                _section('Leitor', [
                  _row(
                    c,
                    title: 'Modo de leitura ao abrir',
                    subtitle: 'Dá para trocar a qualquer momento no leitor',
                    trailing: control(
                      Segmented<bool>(
                        value: paged,
                        onChanged: (value) {
                          setState(() => paged = value);
                          Store.instance.setPreference(
                            'reading_mode',
                            value ? 'pages' : 'continuous',
                          );
                        },
                        segments: const [
                          (
                            value: true,
                            label: 'Páginas',
                            icon: LucideIcons.bookOpen,
                          ),
                          (
                            value: false,
                            label: 'Contínuo',
                            icon: LucideIcons.scrollText,
                          ),
                        ],
                      ),
                    ),
                  ),
                  MergeSemantics(
                    child: _row(
                      c,
                      title: 'Desenhar só com a caneta',
                      subtitle: 'O dedo rola e vira páginas',
                      icon: LucideIcons.penTool,
                      onTap: () => setPenOnly(!penOnly),
                      inline: true,
                      trailing: control(
                        Switch(value: penOnly, onChanged: setPenOnly),
                      ),
                    ),
                  ),
                ], c),
                const SizedBox(height: 24),
                _section('Backup', [
                  _row(
                    c,
                    title: 'Fazer backup',
                    subtitle:
                        'Coleções, partituras e anotações num arquivo .zip',
                    icon: LucideIcons.archive,
                    onTap: backup,
                  ),
                  _row(
                    c,
                    title: 'Restaurar backup',
                    subtitle: 'Substitui a biblioteca atual',
                    icon: LucideIcons.archiveRestore,
                    onTap: restore,
                  ),
                ], c),
                const SizedBox(height: 24),
                _section('Ajuda', [
                  _row(
                    c,
                    title: 'Enviar feedback',
                    subtitle:
                        'Conte o que aconteceu; o registro de erros vai junto',
                    icon: LucideIcons.messageSquare,
                    onTap: sendFeedback,
                  ),
                ], c),
                const SizedBox(height: 24),
                _section('Sobre', [
                  _row(
                    c,
                    title: 'Versão',
                    inline: true,
                    trailing: control(
                      Text(appVersion, style: designText(15, c.tx2)),
                    ),
                  ),
                ], c),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    tr(
                      context,
                      'O Notivo funciona offline. Suas partituras e anotações ficam só neste aparelho e nos backups que você fizer.',
                    ),
                    style: designText(13, c.tx2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void setPenOnly(bool value) {
    setState(() => penOnly = value);
    Store.instance.setPreference('pen_only', value ? '1' : '0');
  }
}

/// The collection's colored circle with its icon.
class CollectionBadge extends StatelessWidget {
  const CollectionBadge({super.key, required this.collection, this.size = 52});
  final Collection collection;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: collection.color.toUpperCase() == '#2E1A6B'
          ? NotivoColors(context).banda
          : _color(collection.color),
    ),
    child: Icon(
      collectionIcon(collection.icon),
      size: size * .46,
      color: _color(collection.iconColor),
    ),
  );
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
    this.onCollectionActions,
  });
  final Collection collection;
  final ScoreSelection selection;
  final VoidCallback? onOpenSelection;
  // Edit or remove this collection (the library owns those flows); gets the
  // collection as it is now, since editing from here changes it.
  final Future<void> Function(Collection current)? onCollectionActions;
  @override
  State<ScoreListScreen> createState() => _ScoreListScreenState();
}

class _ScoreListScreenState extends State<ScoreListScreen> {
  final search = TextEditingController();
  Set<int> get selected => widget.selection.value;
  Future<List<Score>>? future;
  // Index into _sorts: name ascending, name descending, newest, oldest.
  int sort = 0;
  static const _sorts = [
    (LucideIcons.arrowDown01, 'Nome (1 → 9)'),
    (LucideIcons.arrowDown10, 'Nome (9 → 1)'),
    (LucideIcons.clockArrowDown, 'Mais recentes'),
    (LucideIcons.clockArrowUp, 'Mais antigas'),
  ];
  // Kept in state: editing the collection from here changes its name and look.
  late Collection collection = widget.collection;

  Future<void> collectionMenu() async {
    await widget.onCollectionActions?.call(collection);
    final now = (await Store.instance.collections())
        .where((item) => item.id == collection.id)
        .firstOrNull;
    if (!mounted) return;
    if (now == null) return Navigator.pop(context);
    setState(() => collection = now);
    refresh();
  }

  void refresh() => setState(() {
    future = Store.instance.scores(
      collectionId: widget.collection.id,
      search: search.text,
      recent: sort >= 2,
      reverse: sort.isOdd,
    );
  });
  void selectionChanged() {
    if (mounted) setState(() {});
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
    if (await importPdfs(context, widget.collection.id) > 0 && mounted) {
      refresh();
    }
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
    final chosen = await pickCollections(
      context,
      title: 'Coleções',
      subtitle: score.name,
      initial: score.collectionIds.toSet(),
      action: (_) => tr(context, 'Salvar'),
    );
    if (chosen == null || !mounted) return;
    if (chosen.isEmpty &&
        !await confirmSheet(
          context,
          title: 'Remover de todas as coleções?',
          message: deletionNotice(context, 1),
          action: 'Remover e apagar',
        )) {
      return;
    }
    try {
      await Store.instance.setScoreCollections(
        score.id,
        chosen,
        purge: chosen.isNotEmpty,
      );
      if (chosen.isEmpty) {
        widget.selection.replace(selected.difference({score.id}));
      }
      if (!mounted) return;
      refresh();
      if (chosen.isEmpty) {
        offerUndoDeletion(context, 1, () async {
          await Store.instance.setScoreCollections(
            score.id,
            score.collectionIds.toSet(),
          );
          if (mounted) refresh();
        });
      }
    } catch (error) {
      if (mounted) showError(context, 'Não foi possível salvar', error);
    }
  }

  /// Adds every selected score, from any collection, to the chosen collections.
  Future<void> addSelectionToCollections() async {
    final ids = selected;
    final chosen = await pickCollections(
      context,
      title: 'Adicionar à coleção',
      subtitle: plural(
        context,
        ids.length,
        'partitura selecionada',
        'partituras selecionadas',
      ),
      action: (n) => n == 0
          ? tr(context, 'Adicionar')
          : '${tr(context, 'Adicionar a')} ${plural(context, n, 'coleção', 'coleções')}',
    );
    if (chosen == null || chosen.isEmpty) return;
    try {
      await Store.instance.addToCollections(ids, chosen);
      if (mounted) refresh();
    } catch (error) {
      if (mounted) showError(context, 'Não foi possível salvar', error);
    }
  }

  Future<void> openScore(Score score) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(initial: [score], index: 0),
      ),
    );
    if (mounted) refresh();
  }

  Future<void> scoreActions(Score score) async {
    final action = await showActionSheet<String>(
      context,
      title: score.name,
      subtitle: score.collections.join(' · '),
      leading: ScoreThumb(path: score.path, width: 40),
      actions: [
        (
          value: 'open',
          icon: LucideIcons.bookOpen,
          label: tr(context, 'Abrir'),
          destructive: false,
        ),
        (
          value: 'rename',
          icon: LucideIcons.pencil,
          label: tr(context, 'Renomear'),
          destructive: false,
        ),
        (
          value: 'organize',
          icon: LucideIcons.folders,
          label: tr(context, 'Coleções'),
          destructive: false,
        ),
        (
          value: 'remove',
          icon: LucideIcons.trash2,
          label: '${tr(context, 'Remover de')} ${widget.collection.name}',
          destructive: true,
        ),
      ],
    );
    if (action == 'open' && mounted) openScore(score);
    if (!mounted) return;
    if (action == 'rename') await rename(score);
    if (action == 'organize') await organize(score);
    if (action == 'remove') await removeScores([score]);
  }

  Future<void> removeScores(List<Score> scores) async {
    if (scores.isEmpty) return;
    final ids = scores.map((s) => s.id).toSet();
    final collectionId = widget.collection.id;
    try {
      final lost = await Store.instance.orphanedBy([collectionId], ids);
      if (!mounted) return;
      // Deleting asks first, then still offers Undo for a few seconds.
      if (lost > 0 &&
          !await confirmSheet(
            context,
            title: 'Remover da coleção?',
            message: deletionNotice(context, lost),
            action: 'Remover',
          )) {
        return;
      }
      await Store.instance.removeFromCollection(
        collectionId,
        ids,
        purge: lost == 0,
      );
      widget.selection.replace(selected.difference(ids));
      if (!mounted) return;
      refresh();
      if (lost > 0) {
        return offerUndoDeletion(context, lost, () async {
          await Store.instance.addToCollections(ids, [collectionId]);
          if (mounted) refresh();
        });
      }
      showUndo(
        context,
        tr(
          context,
          ids.length == 1
              ? 'Partitura removida da coleção'
              : 'Partituras removidas da coleção',
        ),
        () async {
          try {
            await Store.instance.addToCollections(ids, [collectionId]);
            if (mounted) refresh();
          } catch (error) {
            if (mounted) showError(context, 'Não foi possível desfazer', error);
          }
        },
      );
    } catch (error) {
      if (mounted) showError(context, 'Não foi possível remover', error);
    }
  }

  void openSelected() => widget.onOpenSelection != null
      ? widget.onOpenSelection!()
      : openSelectedScores(context, widget.selection);
  void toggleSelection(Score score) => widget.selection.toggle(score.id);

  Widget _sortButton(NotivoColors c, bool compact) => MenuAnchor(
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(c.card),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    menuChildren: [
      for (var i = 0; i < _sorts.length; i++)
        MenuItemButton(
          leadingIcon: Icon(_sorts[i].$1, size: 18, color: c.tx),
          trailingIcon: i == sort
              ? Icon(LucideIcons.check, size: 18, color: c.accent)
              : null,
          onPressed: () {
            sort = i;
            refresh();
          },
          child: Text(tr(context, _sorts[i].$2), style: designText(15, c.tx)),
        ),
    ],
    builder: (context, controller, _) => Semantics(
      button: true,
      label: '${tr(context, 'Ordenar')}: ${tr(context, _sorts[sort].$2)}',
      excludeSemantics: true,
      child: Material(
        color: c.soft,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(_sorts[sort].$1, size: 18, color: c.tx),
                // Phones keep only the icon; the menu shows the names.
                if (!compact)
                  Text(
                    tr(context, _sorts[sort].$2),
                    style: designText(14, c.tx, weight: FontWeight.w500),
                  ),
                Icon(LucideIcons.chevronDown, size: 16, color: c.tx2),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final width =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).left -
        MediaQuery.paddingOf(context).right;
    final compact = width < 600 || MediaQuery.sizeOf(context).height < 500;
    // Wide screens keep the list at most 840 px wide, centered.
    final gutter = compact ? 20.0 : math.max(40.0, (width - 840) / 2);
    final side = width < 600 ? 12.0 : math.max(96.0, (width - 640) / 2);
    // Selection mode: once anything is selected, a tap toggles instead of opening.
    final selecting = selected.isNotEmpty || widget.onOpenSelection != null;
    return Scaffold(
      body: SafeArea(
        child: DesignViewport(
          child: FutureBuilder<List<Score>>(
            future: future,
            builder: (context, snap) {
              final scores = snap.data ?? const <Score>[];
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
                          compact ? 16 : 40,
                          gutter,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                spacing: 8,
                                children: [
                                  Transform.translate(
                                    offset: const Offset(-10, 0),
                                    child: DesignIcon(
                                      icon: LucideIcons.chevronLeft,
                                      label: 'Voltar',
                                      radius: 22,
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                  CollectionBadge(
                                    collection: collection,
                                    size: compact ? 40 : 48,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          collection.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: designText(
                                            compact ? 22 : 30,
                                            c.tx,
                                            height: 1.15,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          plural(
                                            context,
                                            scores.length,
                                            'partitura',
                                            'partituras',
                                          ),
                                          style: designText(14, c.tx2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.onCollectionActions != null)
                                    DesignIcon(
                                      icon: LucideIcons.ellipsis,
                                      label: 'Ações da coleção',
                                      radius: 22,
                                      color: c.tx2,
                                      onPressed: collectionMenu,
                                    ),
                                  width < 600
                                      ? DesignIcon(
                                          label: 'Importar PDFs',
                                          icon: LucideIcons.fileUp,
                                          onPressed: importFiles,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          background: c.accent,
                                          radius: 22,
                                          size: 20,
                                        )
                                      : DesignButton(
                                          label: 'Importar PDFs',
                                          onPressed: importFiles,
                                          icon: LucideIcons.fileUp,
                                          fill: c.accent,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          weight: FontWeight.w600,
                                        ),
                                ],
                              ),
                              SizedBox(height: compact ? 16 : 24),
                              Row(
                                spacing: 10,
                                children: [
                                  Expanded(
                                    child: SearchField(
                                      controller: search,
                                      onChanged: (_) => refresh(),
                                      hint:
                                          '${tr(context, 'Buscar em')} ${collection.name}',
                                    ),
                                  ),
                                  _sortButton(c, compact),
                                ],
                              ),
                              const SizedBox(height: 16),
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
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              spacing: 16,
                              children: [
                                Icon(
                                  LucideIcons.fileMusic,
                                  size: 44,
                                  color: c.mark,
                                ),
                                Text(
                                  tr(
                                    context,
                                    search.text.trim().isEmpty
                                        ? 'Nenhuma partitura nesta coleção.'
                                        : 'Nenhuma partitura encontrada.',
                                  ),
                                  style: designText(17, c.tx2),
                                ),
                                if (search.text.trim().isEmpty)
                                  FilledButton.icon(
                                    onPressed: importFiles,
                                    icon: const Icon(
                                      LucideIcons.fileUp,
                                      size: 18,
                                    ),
                                    label: Text(tr(context, 'Importar PDFs')),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: gutter),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((context, i) {
                              final score = scores[i];
                              return ScoreRow(
                                name: score.name,
                                path: score.path,
                                collections: score.collections.join(' · '),
                                selected: selected.contains(score.id),
                                onSelect: () => toggleSelection(score),
                                onMenu: () => scoreActions(score),
                                onTap: selecting
                                    ? () => toggleSelection(score)
                                    : () => openScore(score),
                                onLongPress: () => toggleSelection(score),
                              );
                            }, childCount: scores.length),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: selected.isEmpty ? 24 : 120),
                      ),
                    ],
                  ),
                  if (selected.isNotEmpty)
                    Positioned(
                      left: side,
                      right: side,
                      bottom: compact ? 16 : 40,
                      child: SelectionBar(
                        count: selected.length,
                        onClose: widget.selection.clear,
                        onCollections: addSelectionToCollections,
                        // Only scores of this collection can be removed from it.
                        onDelete: picked.isEmpty
                            ? null
                            : () => removeScores(picked),
                        deleteLabel: 'Remover desta coleção',
                        onOpen: openSelected,
                      ),
                    ),
                ],
              );
            },
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
      SheetPrimary(tr(context, 'Salvar'), onPressed: _save),
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
  // Each drawing tool remembers its own color and thickness.
  final toolColors = <String, Color>{
    'pen': noteColors.first,
    'highlighter': noteColors[2],
  };
  final toolSizes = <String, double>{'pen': 1, 'highlighter': 1, 'eraser': 1};
  Color get color => toolColors[tool] ?? toolColors['pen']!;
  double get strokeSize => toolSizes[tool] ?? toolSizes['pen']!;
  bool controlsHidden = false;
  // Export progress from 0 to 1; null when not exporting.
  double? exportProgress;
  // Pages: tap the edges or press a pedal to turn. Continuous: free scroll and zoom.
  // Both fit the page to the width.
  bool paged = true;
  int page = 1, pageCount = 0;
  PdfViewerController? viewer;
  // A stylus stroke is in progress: the finger must not pan underneath it.
  bool drawing = false;
  // Stage mode: app and system bars hidden, no drawing, no closing tabs; turning pages and pinch zoom.
  bool stage = false;
  // First-time explanation of stage mode.
  bool coach = false;
  // Only the pen draws: finger and palm touches scroll instead.
  bool penOnly = false;

  @override
  void initState() {
    super.initState();
    Store.instance.preference('pen_only').then((value) {
      if (mounted && value == '1') setState(() => penOnly = true);
    });
    Store.instance.preference('reading_mode').then((value) {
      if (mounted && value == 'continuous') setState(() => paged = false);
    });
    Store.instance.markOpened(widget.initial.map((score) => score.id));
  }

  void _setPaged(bool value) {
    setState(() => paged = value);
    Store.instance.setPreference(
      'reading_mode',
      paged ? 'pages' : 'continuous',
    );
    // Pages mode starts each page fitted to the width, so drop any zoom.
    if (paged) _fitWidth();
  }

  void _fitWidth() {
    final v = viewer;
    if (v != null) v.goTo(v.calcMatrixFitWidthForPage(pageNumber: page));
  }

  void _turn(int delta) {
    final v = viewer;
    if (v == null) return;
    if (paged) {
      final target = (page + delta).clamp(1, math.max(1, pageCount)).toInt();
      // Top of the next page at the same zoom and sideways position.
      v.goToPosition(
        documentOffset: Offset(
          v.visibleRect.left,
          v.layout.pageLayouts[target - 1].top,
        ),
        duration: const Duration(milliseconds: 200),
      );
      return;
    }
    // Continuous: one screen at a time, keeping the last 15% (the last line) in view.
    final r = v.visibleRect;
    final top = (r.top + delta * r.height * .85)
        .clamp(0.0, math.max(0.0, v.documentSize.height - r.height))
        .toDouble();
    v.goToPosition(
      documentOffset: Offset(r.left, top),
      duration: const Duration(milliseconds: 200),
    );
  }

  Future<void> _enterStage() async {
    final seen = await Store.instance.preference('stage_coach_seen');
    if (!mounted) return;
    setState(() {
      stage = true;
      coach = seen != '1';
    });
    // Status and navigation bars hidden: a swipe from the top only shows
    // them, so the notification shade needs a second, deliberate swipe.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitStage() {
    setState(() {
      stage = false;
      coach = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    if (stage) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _dismissCoach() {
    setState(() => coach = false);
    Store.instance.setPreference('stage_coach_seen', '1');
  }

  /// Bluetooth page-turner pedals send arrow, page or space keys.
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final next = {
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.pageDown,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.enter,
    };
    final previous = {
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.pageUp,
    };
    if (next.contains(event.logicalKey)) {
      _turn(1);
    } else if (previous.contains(event.logicalKey)) {
      _turn(-1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Pages mode: left third goes back, right third forward, middle shows or hides the bars.
  void _onTapZone(TapUpDetails details, double width) {
    final x = details.localPosition.dx / width;
    if (x < 1 / 3) {
      _turn(-1);
    } else if (x > 2 / 3) {
      _turn(1);
    } else if (!stage) {
      setState(() => controlsHidden = !controlsHidden);
    }
  }

  Future<void> leave({bool home = true}) async {
    if (stage) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(context, 'Segure o selo no topo para sair do Modo palco.'),
            ),
          ),
        );
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
      if (mounted) showError(context, 'Falha ao salvar anotações', error);
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
    Store.instance.markOpened(scores.map((score) => score.id));
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
    if (stage) return;
    final score = tabs[index];
    if (!await confirmSheet(
          context,
          title: 'Fechar aba?',
          message:
              '${score.name} ${tr(context, 'sai das abas. A partitura e as anotações continuam salvas.')}',
          action: 'Fechar aba',
          // Closing deletes nothing: violet, not red.
          destructive: false,
        ) ||
        !mounted) {
      return;
    }
    if (tabs.length == 1) return leave(home: false);
    if (!await flushAnnotations() || !mounted) return;
    final currentIndex = tabs.indexWhere((tab) => tab.id == score.id);
    if (currentIndex < 0) return;
    setState(() {
      tabs.removeAt(currentIndex);
      pads.removeWhere((key, _) => key.startsWith('${score.id}:'));
      if (currentIndex < active) active--;
      if (active >= tabs.length) active = tabs.length - 1;
    });
  }

  /// Moves a tab dragged from [from] to [to].
  void _moveTab(int from, int to) {
    final current = tabs[active];
    setState(() {
      tabs.insert(to, tabs.removeAt(from));
      active = tabs.indexOf(current);
    });
  }

  Future<void> _customColor() async {
    final picked = await showAppSheet<Color>(
      context,
      builder: (_) => ColorPickerSheet(initial: color),
    );
    if (picked != null && mounted) setState(() => toolColors[tool] = picked);
  }

  /// Phones: the open scores as a list, to switch, close or add one.
  Future<void> _tabsSheet() async {
    final c = NotivoColors(context);
    final action = await showAppSheet<int>(
      context,
      builder: (ctx) => AppSheet(
        title: tr(ctx, 'Partituras abertas'),
        subtitle: tabs.length > 1
            ? tr(ctx, 'Segure e arraste para mudar a ordem')
            : null,
        list: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rebuilds itself after a drag; the reader's tabs change too.
            StatefulBuilder(
              builder: (ctx, setSheet) => ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) => setSheet(() => _moveTab(from, to)),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    ReorderableDelayedDragStartListener(
                      key: ValueKey(tabs[i].id),
                      index: i,
                      child: ListTile(
                        minTileHeight: 56,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        selected: i == active,
                        selectedTileColor: c.active,
                        leading: ScoreThumb(path: tabs[i].path, width: 32),
                        title: Text(
                          tabs[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: DesignIcon(
                          icon: LucideIcons.x,
                          label: 'Fechar aba',
                          onPressed: () => Navigator.pop(ctx, -1 - i),
                          color: c.tx2,
                          size: 18,
                        ),
                        onTap: () => Navigator.pop(ctx, i),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              minTileHeight: 56,
              leading: Icon(LucideIcons.plus, color: c.accent),
              title: Text(
                tr(ctx, 'Abrir outra partitura'),
                style: designText(16, c.accent, weight: FontWeight.w500),
              ),
              onTap: () => Navigator.pop(ctx, tabs.length),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == tabs.length) return addTab();
    if (action < 0) return closeTab(-1 - action);
    setState(() => active = action);
  }

  /// The most recently edited page of the active tab that [usable] accepts.
  _AnnotationPadState? _latestPage(bool Function(_AnnotationPadState) usable) {
    final pages =
        pads.entries
            .where((entry) => entry.key.startsWith('${tabs[active].id}:'))
            .map((entry) => entry.value.currentState)
            .whereType<_AnnotationPadState>()
            .where(usable)
            .toList()
          ..sort(
            (a, b) => (b.lastEdited ?? DateTime(0)).compareTo(
              a.lastEdited ?? DateTime(0),
            ),
          );
    return pages.firstOrNull;
  }

  _AnnotationPadState? get _undoPage =>
      _latestPage((page) => page.undoStack.isNotEmpty);
  _AnnotationPadState? get _redoPage =>
      _latestPage((page) => page.redoStack.isNotEmpty);

  /// Undo or redo the last edit of this score and bring its page into view.
  Future<void> _step(_AnnotationPadState? pad, bool undo) async {
    if (pad == null) return;
    if (pad.widget.page != page) {
      viewer?.goToPage(
        pageNumber: pad.widget.page,
        anchor: paged ? PdfPageAnchor.all : PdfPageAnchor.top,
      );
    }
    await (undo ? pad.undo() : pad.redo());
  }

  void _togglePenOnly() {
    setState(() => penOnly = !penOnly);
    Store.instance.setPreference('pen_only', penOnly ? '1' : '0');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              penOnly
                  ? 'Só a caneta desenha. O dedo rola e vira páginas.'
                  : 'Dedo e caneta desenham.',
            ),
          ),
        ),
      );
  }

  Future<void> _export(Score score) async {
    setState(() => exportProgress = 0);
    PdfDocument? document;
    try {
      if (!await flushAnnotations()) return;
      document = await PdfDocument.openFile(score.path);
      final exported = pw.Document();
      for (final page in document.pages) {
        if (mounted) {
          setState(
            () =>
                exportProgress = page.pageNumber / (document!.pages.length + 1),
          );
        }
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
            stroke['tool'] == 'highlighter'
                ? (highlighterOpacity * 255).round()
                : 255,
          );
          // Same width as on screen: points scaled to the raster's pixels per PDF point.
          final width = strokeWidth(stroke) * scale;
          if (points.length == 1)
            img.fillCircle(
              raster,
              x: ((points.first['x'] as num) * raster.width).round(),
              y: ((points.first['y'] as num) * raster.height).round(),
              radius: (width / 2).round(),
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
              thickness: width,
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
      if (mounted) showError(context, 'Falha ao exportar', error);
    } finally {
      await document?.dispose();
      if (mounted) setState(() => exportProgress = null);
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
    const toolbarHeight = 64.0;
    final headerHeight = 56 + toolbarHeight + 1;
    const handleHeight = 32.0;
    // Stage mode reads like the Navigate tool, whatever tool was picked.
    final activeTool = stage ? 'navigate' : tool;
    // With "pen only" the finger keeps scrolling and zooming while the pen draws.
    final fingerNavigates = activeTool == 'navigate' || penOnly;
    // Pages are fitted to the width, so they may run taller than the screen:
    // the finger scrolls in both modes.
    final canPan = fingerNavigates && !drawing;
    // In stage mode the page starts below the badge (6 + 44 touch area + 6).
    final viewerTop = stage
        ? 56.0
        : controlsHidden
        ? handleHeight + 6
        : headerHeight;
    // Pages turn by tapping the edges; in stage mode continuous reading does too.
    final tapZones = (paged && fingerNavigates) || stage;
    Widget tabChip(int i) => Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => active = i),
        child: Container(
          height: 56,
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active == i ? c.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  tabs[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: designText(
                    14,
                    active == i ? c.tx : c.tx2,
                    weight: active == i ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              DesignIcon(
                icon: LucideIcons.x,
                label: 'Fechar aba',
                onPressed: () => closeTab(i),
                extent: 40,
                radius: 8,
                size: 14,
                color: active == i ? c.tx : c.tx2,
              ),
            ],
          ),
        ),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave(home: false);
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: SafeArea(
            child: DesignViewport(
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: c.soft)),
                  Positioned(
                    top: viewerTop,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: PdfViewer.file(
                      score.path,
                      key: ValueKey(score.id),
                      params: PdfViewerParams(
                        margin: 0,
                        sizeDelegateProvider:
                            const PdfViewerSizeDelegateProviderLegacy(
                              calculateInitialZoom: _fitPageWidth,
                            ),
                        panEnabled: canPan,
                        // Pinch zoom in every mode; a page turn keeps the zoom.
                        scaleEnabled: canPan,
                        loadingBannerBuilder: (context, _, _) =>
                            const Center(child: CircularProgressIndicator()),
                        errorBannerBuilder: (context, error, _, _) {
                          logError('Open ${score.name}: $error');
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '${tr(context, 'Não foi possível abrir a partitura')}. ${tr(context, errorReason(error))}',
                                textAlign: TextAlign.center,
                                style: designText(16, c.tx2),
                              ),
                            ),
                          );
                        },
                        // Keys are handled above, the same way in both modes.
                        keyHandlerParams: const PdfViewerKeyHandlerParams(
                          enabled: false,
                        ),
                        onViewerReady: (document, controller) => setState(() {
                          viewer = controller;
                          pageCount = document.pages.length;
                          page = controller.pageNumber ?? 1;
                        }),
                        onPageChanged: (number) {
                          if (number != null && mounted) {
                            setState(() => page = number);
                          }
                        },
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
                              tool: activeTool,
                              color: color,
                              size: strokeSize,
                              penOnly: penOnly,
                              onEdit: () {
                                if (mounted) setState(() {});
                              },
                              onDrawing: (value) {
                                if (mounted && penOnly) {
                                  setState(() => drawing = value);
                                }
                              },
                            ),
                          ];
                        },
                      ),
                    ),
                  ),
                  // Always in the tree so the header below keeps its state (tab scroll).
                  Positioned(
                    top: viewerTop,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: !tapZones,
                      child: LayoutBuilder(
                        builder: (context, bounds) => GestureDetector(
                          // Translucent: the viewer underneath still gets the touches.
                          behavior: HitTestBehavior.translucent,
                          // The pen keeps drawing; only the finger turns pages.
                          supportedDevices: activeTool == 'navigate'
                              ? null
                              : const {PointerDeviceKind.touch},
                          onTapUp: (details) =>
                              _onTapZone(details, bounds.maxWidth),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  if (!controlsHidden && !stage)
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 6 : 12,
                                ),
                                child: Row(
                                  spacing: compact ? 0 : 4,
                                  children: [
                                    DesignIcon(
                                      icon: LucideIcons.house,
                                      label: 'Início',
                                      size: 20,
                                      onPressed: leave,
                                    ),
                                    if (compact)
                                      Expanded(
                                        child: Semantics(
                                          button: true,
                                          label:
                                              '${score.name}, ${plural(context, tabs.length, 'aba aberta', 'abas abertas')}',
                                          excludeSemantics: true,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: _tabsSheet,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              child: Row(
                                                spacing: 6,
                                                children: [
                                                  Flexible(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          score.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: designText(
                                                            15,
                                                            c.tx,
                                                            weight:
                                                                FontWeight.w600,
                                                            height: 1.3,
                                                          ),
                                                        ),
                                                        Text(
                                                          plural(
                                                            context,
                                                            tabs.length,
                                                            'aba aberta',
                                                            'abas abertas',
                                                          ),
                                                          style: designText(
                                                            12,
                                                            c.tx2,
                                                            height: 1.3,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    LucideIcons.chevronDown,
                                                    size: 16,
                                                    color: c.tx,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      // Hold a tab and drag it to reorder; "+" follows the
                                      // last tab, after a divider, like browser tabs.
                                      Expanded(
                                        child: ReorderableListView(
                                          scrollDirection: Axis.horizontal,
                                          buildDefaultDragHandles: false,
                                          onReorderItem: _moveTab,
                                          // The held tab lifts into a card; the others slide aside.
                                          proxyDecorator: (child, _, animation) =>
                                              AnimatedBuilder(
                                                animation: animation,
                                                builder: (context, child) {
                                                  final t = Curves.easeOut
                                                      .transform(animation.value);
                                                  return Transform.scale(
                                                    scale: 1 + .04 * t,
                                                    child: Material(
                                                      color: c.bg,
                                                      elevation: 6 * t,
                                                      shadowColor: c.accent
                                                          .withValues(alpha: .35),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      clipBehavior: Clip.antiAlias,
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                                child: child,
                                              ),
                                          footer: Row(
                                            children: [
                                              Container(
                                                width: 1,
                                                height: 24,
                                                color: c.line,
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                              ),
                                              DesignIcon(
                                                icon: LucideIcons.plus,
                                                label: 'Abrir outra partitura',
                                                onPressed: addTab,
                                                color: c.tx2,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                          children: [
                                            for (
                                              var i = 0;
                                              i < tabs.length;
                                              i++
                                            )
                                              ReorderableDelayedDragStartListener(
                                                key: ValueKey(tabs[i].id),
                                                index: i,
                                                child: tabChip(i),
                                              ),
                                          ],
                                        ),
                                      ),
                                    compact
                                        ? DesignIcon(
                                            icon: LucideIcons.lock,
                                            label: 'Modo palco',
                                            onPressed: _enterStage,
                                            color: Colors.white,
                                            background: const Color(0xff2e1a6b),
                                            radius: 22,
                                            size: 18,
                                          )
                                        : DesignButton(
                                            label: 'Modo palco',
                                            icon: LucideIcons.lock,
                                            onPressed: _enterStage,
                                            fill: const Color(0xff2e1a6b),
                                            color: Colors.white,
                                            weight: FontWeight.w600,
                                            horizontal: 14,
                                          ),
                                    DesignIcon(
                                      icon: LucideIcons.chevronUp,
                                      label: 'Recolher abas e ferramentas',
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
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: c.rowLine),
                                  ),
                                ),
                                child: ReaderToolbar(
                                  tool: tool,
                                  color: color,
                                  colors: noteColors,
                                  onTool: (value) =>
                                      setState(() => tool = value),
                                  onColor: (value) =>
                                      setState(() => toolColors[tool] = value),
                                  onCustom: _customColor,
                                  onUndo: _undoPage == null
                                      ? null
                                      : () => _step(_undoPage, true),
                                  onRedo: _redoPage == null
                                      ? null
                                      : () => _step(_redoPage, false),
                                  size: strokeSize,
                                  onSize: (value) =>
                                      setState(() => toolSizes[tool] = value),
                                  penOnly: penOnly,
                                  onPenOnly: _togglePenOnly,
                                  onExport: () => _export(score),
                                  exportProgress: exportProgress,
                                  paged: paged,
                                  onPaged: _setPaged,
                                  compact: compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (controlsHidden && !stage)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: DesignPill(
                          radius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                          child: SizedBox(
                            width: 72,
                            height: handleHeight,
                            child: DesignIcon(
                              icon: LucideIcons.chevronDown,
                              label: 'Mostrar abas e ferramentas',
                              onPressed: () =>
                                  setState(() => controlsHidden = false),
                              extent: handleHeight,
                              radius: 16,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (stage && coach)
                    Positioned.fill(
                      child: _StageCoach(paged: paged, onDone: _dismissCoach),
                    ),
                  if (stage)
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _StagePill(paged: paged, onExit: _exitStage),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stage mode badge: holding it for a second leaves stage mode, so a stray tap can't.
class _StagePill extends StatefulWidget {
  const _StagePill({required this.paged, required this.onExit});
  final bool paged;
  final VoidCallback onExit;
  @override
  State<_StagePill> createState() => _StagePillState();
}

class _StagePillState extends State<_StagePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController hold =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            hold.reset();
            widget.onExit();
          }
        });

  @override
  void dispose() {
    hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = tr(
      context,
      widget.paged ? 'Modo palco' : 'Modo palco · Contínuo',
    );
    return Semantics(
      button: true,
      label: '$title. ${tr(context, 'Segure para sair')}',
      onLongPress: widget.onExit,
      excludeSemantics: true,
      child: GestureDetector(
        // Opaque: the 44 px touch area around the slim badge still counts.
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => hold.forward(),
        onTapUp: (_) => hold.reverse(),
        onTapCancel: () => hold.reverse(),
        child: Container(
          // Full pill (radius = half the height) with the ring inset 4 px on
          // every side, so its circle shares the center of the rounded end.
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          decoration: BoxDecoration(
            color: const Color(0xff2e1a6b),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff1f1340).withValues(alpha: .2),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              SizedBox.square(
                dimension: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: hold,
                      builder: (_, _) => CircularProgressIndicator(
                        value: hold.value,
                        strokeWidth: 2,
                        color: const Color(0xffc9b6f5),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const Icon(LucideIcons.lock, size: 16, color: Colors.white),
                  ],
                ),
              ),
              Text(
                title,
                style: designText(
                  14,
                  Colors.white,
                  weight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              Container(width: 1, height: 16, color: Colors.white30),
              Text(
                tr(context, 'Segure para sair'),
                style: designText(13, const Color(0xffe4dbfb), height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First-time explanation of stage mode, with the tap zones drawn on the page.
class _StageCoach extends StatelessWidget {
  const _StageCoach({required this.paged, required this.onDone});
  final bool paged;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    Widget zone(bool left) => Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: left
                ? const BorderSide(color: Colors.white54, width: 2)
                : BorderSide.none,
            left: left
                ? BorderSide.none
                : const BorderSide(color: Colors.white54, width: 2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Icon(
              paged
                  ? (left ? LucideIcons.chevronLeft : LucideIcons.chevronRight)
                  : (left ? LucideIcons.chevronUp : LucideIcons.chevronDown),
              size: 32,
              color: Colors.white,
            ),
            Text(
              tr(
                context,
                paged
                    ? (left ? 'Página anterior' : 'Próxima página')
                    : (left ? 'Voltar uma tela' : 'Avançar uma tela'),
              ),
              textAlign: TextAlign.center,
              style: designText(15, Colors.white, weight: FontWeight.w600),
            ),
            Text(
              tr(
                context,
                left ? 'toque aqui ou pedal ←' : 'toque aqui ou pedal →',
              ),
              textAlign: TextAlign.center,
              style: designText(12, const Color(0xffe4dbfb)),
            ),
          ],
        ),
      ),
    );
    return ColoredBox(
      color: const Color(0x8c1f1340),
      child: Stack(
        children: [
          Row(children: [zone(true), const Spacer(), zone(false)]),
          Center(
            child: Container(
              width: 280,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Text(
                    tr(context, 'Modo palco ligado'),
                    style: designText(20, c.tx, weight: FontWeight.w700),
                  ),
                  for (final line in [
                    'Anotações ficam travadas; o zoom com pinça continua',
                    paged ? 'Vire com toque nas bordas ou com o pedal' : 'Role com o dedo, ou avance uma tela com toque nas bordas ou com o pedal',
                    'As abas não fecham por engano',
                    'Para sair, segure o selo no topo por 1 segundo',
                  ])
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Icon(
                            LucideIcons.circle,
                            size: 6,
                            color: c.accent,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tr(context, line),
                            style: designText(14, c.tx),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onDone,
                      child: Text(tr(context, 'Entendi')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens scores with the widest page filling the viewer's width.
double? _fitPageWidth(
  PdfDocument document,
  PdfViewerController controller,
  double fitZoom,
  double coverZoom,
) =>
    controller.viewSize.width /
    document.pages.map((page) => page.width).reduce(math.max);

/// Undo steps kept per page, in memory and in the database.
const maxUndoSteps = 50;

class AnnotationPad extends StatefulWidget {
  const AnnotationPad({
    super.key,
    required this.scoreId,
    required this.page,
    required this.tool,
    required this.color,
    this.size = 1,
    this.penOnly = false,
    this.onEdit,
    this.onDrawing,
  });
  final int scoreId;
  final int page;
  final String tool;
  final Color color;
  final double size;
  final bool penOnly;
  // Undo/redo availability changed.
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onDrawing;

  @override
  State<AnnotationPad> createState() => _AnnotationPadState();
}

class _AnnotationPadState extends State<AnnotationPad> {
  List<Map<String, dynamic>> strokes = [];
  List<List<Map<String, dynamic>>> undoStack = [];
  // Redo lives only in memory; the undo history is what gets saved.
  List<List<Map<String, dynamic>>> redoStack = [];
  Map<String, dynamic>? current;
  DateTime? lastEdited;
  bool ready = false;
  int? pointer;
  // Where the eraser is, touching or hovering with the pen; null hides the ring.
  Offset? eraserAt;
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
          // Pages saved before the limit existed may carry a longer history.
          undoStack = history.length > maxUndoSteps
              ? history.sublist(history.length - maxUndoSteps)
              : history;
          lastEdited = edited;
          ready = true;
        });
      widget.onEdit?.call();
    } catch (error) {
      if (mounted) showError(context, 'Falha ao carregar anotações', error);
    }
  }

  List<Map<String, dynamic>> _copyStrokes() => strokes
      .map(
        (stroke) => {
          'tool': stroke['tool'],
          'color': stroke['color'],
          if (stroke['size'] != null) 'size': stroke['size'],
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
    // Bounded: each step is a full copy of the page, saved on every stroke.
    if (undoStack.length > maxUndoSteps) undoStack.removeAt(0);
    redoStack.clear();
    if (widget.tool == 'eraser') {
      _erase(position, size);
    } else {
      current = {
        'tool': widget.tool,
        'color': widget.color.toARGB32(),
        'size': widget.size,
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
    final reach = eraserRadius * widget.size;
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
        if ((target - (start + segment * t)).distance < reach) return true;
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
    widget.onEdit?.call();
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
      if (mounted) showError(context, 'Falha ao salvar anotações', error);
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
    redoStack.add(_copyStrokes());
    setState(() => strokes = undoStack.removeLast());
    await _commit();
  }

  Future<void> redo() async {
    if (redoStack.isEmpty) return;
    undoStack.add(_copyStrokes());
    if (undoStack.length > maxUndoSteps) undoStack.removeAt(0);
    setState(() => strokes = redoStack.removeLast());
    await _commit();
  }

  void _aim(Offset? position) {
    final at = widget.tool == 'eraser' ? position : null;
    if (at != eraserAt) setState(() => eraserAt = at);
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !ready || widget.tool == 'navigate',
    child: MouseRegion(
      // A hovering pen (S Pen) shows the ring before it touches.
      onHover: (event) => pointer == null ? _aim(event.localPosition) : null,
      onExit: (_) => pointer == null ? _aim(null) : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (pointer != null || event.buttons != kPrimaryButton) return;
          if (widget.penOnly && event.kind == PointerDeviceKind.touch) return;
          pointer = event.pointer;
          _aim(event.localPosition);
          _start(event.localPosition, context.size!);
          widget.onDrawing?.call(true);
        },
        onPointerMove: (event) {
          if (event.pointer != pointer) return;
          _aim(event.localPosition);
          _move(event.localPosition, context.size!);
        },
        onPointerUp: (event) {
          if (event.pointer != pointer) return;
          pointer = null;
          // A pen lifted but still hovering keeps the ring; the finger hides it.
          if (event.kind != PointerDeviceKind.stylus) _aim(null);
          widget.onDrawing?.call(false);
          _commit();
        },
        onPointerCancel: (event) {
          if (event.pointer != pointer) return;
          pointer = null;
          current = null;
          eraserAt = null;
          if (undoStack.isNotEmpty) strokes = undoStack.removeLast();
          widget.onDrawing?.call(false);
          setState(() {});
        },
        child: CustomPaint(
          painter: _StrokePainter([...strokes, if (current != null) current!]),
          foregroundPainter: eraserAt == null || widget.tool != 'eraser'
              ? null
              : _EraserRing(
                  eraserAt!,
                  eraserRadius * widget.size,
                  NotivoColors(context).tx2,
                ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

/// The eraser's reach around the finger or pen, the same radius [_erase] uses.
class _EraserRing extends CustomPainter {
  const _EraserRing(this.center, this.radius, this.color);
  final Offset center;
  final double radius;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: .12),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _EraserRing old) =>
      old.center != center || old.radius != radius || old.color != color;
}

/// Width in PDF points; the overlay is laid out in points, so screen and export match.
double strokeWidth(Map<String, dynamic> stroke) =>
    (stroke['tool'] == 'highlighter' ? highlighterWidth : penWidth) *
    ((stroke['size'] as num?) ?? 1).toDouble();

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
            .withValues(alpha: highlight ? highlighterOpacity : 1)
        ..strokeWidth = strokeWidth(stroke)
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
