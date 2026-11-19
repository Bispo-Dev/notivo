import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';

const files = [
  ['poppins', 'Poppins-Regular.ttf'],
  ['poppins', 'Poppins-Medium.ttf'],
  ['poppins', 'Poppins-SemiBold.ttf'],
  ['sourceserif4', 'SourceSerif4[opsz,wght].ttf'],
  ['sourceserif4', 'OFL.txt'],
  ['poppins', 'OFL.txt'],
];
mkdirSync('app/assets/fonts', { recursive: true });
const hashes = [];
for (const [family, name] of files) {
  const response = await fetch(`https://api.github.com/repos/google/fonts/contents/ofl/${family}/${encodeURIComponent(name)}`, { headers: { 'User-Agent': 'notivo-font-setup' } });
  if (!response.ok) throw new Error(`Google Fonts API failed for ${name}: ${response.status}`);
  const item = await response.json();
  const bytes = Buffer.from(await (await fetch(item.download_url)).arrayBuffer());
  const gitHash = createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex');
  if (gitHash !== item.sha) throw new Error(`Google Fonts Git blob hash mismatch for ${name}`);
  const target = name === 'OFL.txt' ? `${family}-OFL.txt` : name;
  writeFileSync(`app/assets/fonts/${target}`, bytes);
  hashes.push(`${createHash('sha256').update(bytes).digest('hex')}  ${target}`);
}
writeFileSync('app/assets/fonts/SHA256SUMS.txt', `${hashes.join('\n')}\n`);
console.log('Downloaded and verified Poppins and Source Serif 4 from the Google Fonts repository.');
