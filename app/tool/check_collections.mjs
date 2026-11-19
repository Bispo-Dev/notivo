import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const source = fs.readFileSync(path.join(root, 'app/lib/main.dart'), 'utf8');
const db = new DatabaseSync(':memory:');
db.exec('PRAGMA foreign_keys=ON');
for (const [_, sql] of source.matchAll(/'(CREATE TABLE[^']+)'/g)) db.exec(sql);
db.exec(`INSERT INTO collections VALUES(1,'A','#6D3BD2','music',0),(2,'B','#2E1A6B','drum',1);
INSERT INTO scores VALUES(7,'Original','original.pdf','/original.pdf','2026-11-11');
INSERT INTO collection_scores VALUES(1,7),(2,7);
INSERT INTO annotations VALUES(7,1,'[]','[]','2026-11-11');`);
const start = source.indexOf('Future<void> deleteCollection');
const method = source.slice(start, source.indexOf('Future<List<Score>> scores', start));
assert(method.includes('.transaction('));
const commands = [...method.matchAll(/txn\.delete\(\s*'([^']+)',\s*where:\s*'([^']+)'/g)];
assert.deepEqual(commands.map((m) => m[1]), ['collection_scores', 'collections']);
for (const id of [1,2]) {
  db.exec('BEGIN');
  for (const [_, table, where] of commands) db.prepare(`DELETE FROM ${table} WHERE ${where}`).run(id);
  db.exec('COMMIT');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM scores').get().n, 1);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM annotations').get().n, 1);
  assert.equal(db.prepare('SELECT path FROM scores').get().path, '/original.pdf');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM collections').get().n, 2-id);
}
assert(!source.includes('SELECT COUNT(*) AS n FROM collections'), 'Empty libraries must not trigger reseeding');
assert(source.indexOf('const seeds') > source.indexOf('onCreate:'));
assert(source.indexOf('const seeds') < source.indexOf("await db.execute('PRAGMA"));
for (const file of fs.readdirSync(path.join(root, 'app/lib')).filter((name) => name.endsWith('.dart'))) {
  const code = fs.readFileSync(path.join(root, 'app/lib', file), 'utf8');
  assert(!/\bshowDialog\s*[(<]|\bAlertDialog\s*\(/.test(code), `Dialog remains in ${file}`);
}
db.close();
console.log('PASS: collection removal preserves scores/annotations, supports an empty library, and app dialogs use sheets.');
