import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const source = 'docs/notivo-manual-de-marca/notivo-icone-app-principal.svg';
const svg = fs.readFileSync(path.join(root, source), 'utf8');
const attrs = (tag) => Object.fromEntries([...tag.matchAll(/([\w:-]+)="([^"]*)"/g)].map((m) => [m[1], m[2]]));
const rect = attrs(svg.match(/<rect\b[^>]*>/)[0]);
const mark = attrs(svg.match(/<path\b[^>]*>/)[0]);
const transform = mark.transform.match(/^translate\(([-\d.]+) ([-\d.]+)\) scale\(([-\d.]+)\) translate\(([-\d.]+) ([-\d.]+)\)$/);
assert(transform, 'Official icon transform changed; review before generating.');
assert.equal(rect.width, rect.height);
assert.equal(rect.fill, '#6D3BD2');
assert.equal(mark.fill, '#FFFFFF');
const size = Number(rect.width), radius = Number(rect.rx), opposite = size - radius;
const vector = (body) => `<!-- Generated from ${source}; do not redraw the brand. -->\n<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="${size}" android:viewportHeight="${size}">\n${body}\n</vector>\n`;
const symbol = `  <group android:translateX="${transform[1]}" android:translateY="${transform[2]}">\n    <group android:scaleX="${transform[3]}" android:scaleY="${transform[3]}">\n      <group android:translateX="${transform[4]}" android:translateY="${transform[5]}">\n        <path android:fillColor="${mark.fill}" android:pathData="${mark.d}" />\n      </group>\n    </group>\n  </group>`;
const background = `  <path android:fillColor="${rect.fill}" android:pathData="M${radius},0 H${opposite} A${radius},${radius} 0 0,1 ${size},${radius} V${opposite} A${radius},${radius} 0 0,1 ${opposite},${size} H${radius} A${radius},${radius} 0 0,1 0,${opposite} V${radius} A${radius},${radius} 0 0,1 ${radius},0 Z" />`;
const resource = path.join(root, 'app/android/app/src/main/res');
fs.writeFileSync(path.join(resource, 'mipmap-anydpi/ic_launcher.xml'), vector(`${background}\n${symbol}`));
// Android exposes the central 72dp of a 108dp adaptive layer.
fs.writeFileSync(path.join(resource, 'drawable/notivo_launcher_foreground.xml'), vector(`  <group android:pivotX="${size / 2}" android:pivotY="${size / 2}" android:scaleX="0.6666666667" android:scaleY="0.6666666667">\n${symbol}\n  </group>`));
fs.writeFileSync(path.join(resource, 'values/colors.xml'), `<resources>\n    <color name="notivo_launcher_background">${rect.fill}</color>\n</resources>\n`);
console.log(`Android icons generated from ${source}: original path, transform, colors and radius ${rect.rx}/${rect.width}.`);
