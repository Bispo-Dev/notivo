import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { inflateRawSync } from 'node:zlib';

const dir = 'app/assets/fonts';
mkdirSync(dir, { recursive: true });
const hashes = [];
const save = (name, bytes) => {
  writeFileSync(`${dir}/${name}`, bytes);
  hashes.push(`${createHash('sha256').update(bytes).digest('hex')}  ${name}`);
};

// Inter: static weights from the official rsms/inter release, pinned by SHA-256.
const interZip = 'https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip';
const interSha = '9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e';
const zip = Buffer.from(await (await fetch(interZip)).arrayBuffer());
if (createHash('sha256').update(zip).digest('hex') !== interSha) {
  throw new Error('Inter release SHA-256 mismatch');
}
const wanted = {
  'extras/ttf/Inter-Regular.ttf': 'Inter-Regular.ttf',
  'extras/ttf/Inter-Medium.ttf': 'Inter-Medium.ttf',
  'extras/ttf/Inter-SemiBold.ttf': 'Inter-SemiBold.ttf',
  'extras/ttf/Inter-Bold.ttf': 'Inter-Bold.ttf',
  'LICENSE.txt': 'inter-OFL.txt',
};
// Walk the zip central directory (end record is in the last 64 KiB).
const end = zip.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
let at = zip.readUInt32LE(end + 16);
for (let i = 0; i < zip.readUInt16LE(end + 10); i++) {
  const method = zip.readUInt16LE(at + 10);
  const size = zip.readUInt32LE(at + 20);
  const nameLength = zip.readUInt16LE(at + 28);
  const extra = zip.readUInt16LE(at + 30) + zip.readUInt16LE(at + 32);
  const name = zip.toString('utf8', at + 46, at + 46 + nameLength);
  const local = zip.readUInt32LE(at + 42);
  at += 46 + nameLength + extra;
  if (!wanted[name]) continue;
  const start = local + 30 + zip.readUInt16LE(local + 26) + zip.readUInt16LE(local + 28);
  const data = zip.subarray(start, start + size);
  save(wanted[name], method === 8 ? inflateRawSync(data) : data);
  delete wanted[name];
}
if (Object.keys(wanted).length) throw new Error(`Missing in Inter zip: ${Object.keys(wanted)}`);

// Source Serif 4: Google Fonts repository, verified by Git blob hash.
for (const [name, target] of [
  ['SourceSerif4[opsz,wght].ttf', 'SourceSerif4[opsz,wght].ttf'],
  ['OFL.txt', 'sourceserif4-OFL.txt'],
]) {
  const response = await fetch(`https://api.github.com/repos/google/fonts/contents/ofl/sourceserif4/${encodeURIComponent(name)}`, { headers: { 'User-Agent': 'notivo-font-setup' } });
  if (!response.ok) throw new Error(`Google Fonts API failed for ${name}: ${response.status}`);
  const item = await response.json();
  const bytes = Buffer.from(await (await fetch(item.download_url)).arrayBuffer());
  const gitHash = createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex');
  if (gitHash !== item.sha) throw new Error(`Google Fonts Git blob hash mismatch for ${name}`);
  save(target, bytes);
}

writeFileSync(`${dir}/SHA256SUMS.txt`, `${hashes.join('\n')}\n`);
console.log('Downloaded and verified Inter and Source Serif 4.');
