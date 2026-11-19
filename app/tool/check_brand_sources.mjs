import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const paths = (svg) => [...svg.matchAll(/<path\b[^>]*\bd="([^"]*)"/g)].map((m) => m[1]);
const folder = 'app/docs/notivo-manual-de-marca/';
const dart = read('app/lib/brand.dart');
const literal = (name) => {
  const match = dart.match(new RegExp(`const\\s+${name}\\s*=\\s*r'''([\\s\\S]*?)'''`));
  assert(match, `Missing brand path constant: ${name}`);
  return match[1];
};
const logo = paths(read(folder + 'notivo-logo-horizontal-claro.svg'));
assert.equal(literal('_symbolSvgPath'), paths(read(folder + 'notivo-simbolo-violeta.svg'))[0]);
assert.equal(literal('_horizontalMarkSvgPath'), logo[0]);
assert.equal(literal('_horizontalLettersSvgPath'), logo[1]);
for (const variant of ['branco', 'escuro', 'noite']) {
  assert.deepEqual(paths(read(folder + `notivo-logo-horizontal-${variant}.svg`)), logo);
}
const icon = paths(read(folder + 'notivo-icone-app-principal.svg'))[0];
for (const resource of ['drawable/notivo_launcher_foreground.xml', 'mipmap-anydpi/ic_launcher.xml']) {
  const xml = read('app/android/app/src/main/res/' + resource);
  assert(xml.includes(`android:pathData="${icon}"`));
  assert(xml.includes('android:translateX="-32.75" android:translateY="-35.54"'));
  assert(xml.includes('android:scaleX="7.7511" android:scaleY="7.7511"'));
}
console.log('PASS: Flutter symbol/letter outlines and Android icon match official SVG paths and transforms.');
