/* Generate native platform icons from the anchored BlazeDevStudio v3 LAN
 * SVG. This build-only script uses sharp 0.34.4 (Apache-2.0). It does not
 * modify the official source B geometry or access remote resources. The
 * product-only overlay is composed in a separate local SVG.
 */
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const app = path.resolve(__dirname, '../..');
const source = path.join(app, 'assets/branding/blazedevstudio-v3/lan-hud.svg');
const transparent = path.join(app, 'assets/branding/blazedevstudio-v3/lan-hud-transparent.svg');
const dest = path.join(app, 'assets/icons');

function makeIco(buffers, sizes) {
  const header = Buffer.alloc(6 + sizes.length * 16);
  header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2);
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  for (let i = 0; i < sizes.length; i++) {
    const pos = 6 + i * 16;
    header[pos] = sizes[i] === 256 ? 0 : sizes[i];
    header[pos + 1] = sizes[i] === 256 ? 0 : sizes[i];
    header[pos + 2] = 0; header[pos + 3] = 0;
    header.writeUInt16LE(1, pos + 4);
    header.writeUInt16LE(32, pos + 6);
    header.writeUInt32LE(buffers[i].length, pos + 8);
    header.writeUInt32LE(offset, pos + 12);
    offset += buffers[i].length;
  }
  return Buffer.concat([header, ...buffers]);
}

async function main() {
  await fs.mkdir(dest, {recursive: true});
  const sizes = [16,24,32,48,64,72,96,128,144,192,256,512];
  const rendered = new Map();
  for (const size of sizes) {
    const bytes = await sharp(source, {density: 288})
      .resize(size, size, {fit: 'fill'}).png().toBuffer();
    await fs.writeFile(path.join(dest, `v3-icon-${size}.png`), bytes);
    rendered.set(size, bytes);
  }
  const icoSizes = [16,24,32,48,64,128,256];
  await fs.writeFile(path.join(dest, 'lan_messenger.ico'),
    makeIco(icoSizes.map(s => rendered.get(s)), icoSizes));
  // Android masks adaptive icons to a centered safe area (~66% diameter).
  // A full-bleed PNG clips the LAN node badge on round/other launchers.
  // Scale the ENTIRE unmodified product SVG into the 432px foreground,
  // keeping all nodes inside the 72..360px central adaptive safe zone.
  await sharp(transparent, {density: 288})
    .resize(336, 336, {fit: 'contain'})
    .extend({top: 48, bottom: 48, left: 48, right: 48,
      background: {r: 0, g: 0, b: 0, alpha: 0}})
    .png().toFile(path.join(dest, 'v3-adaptive-foreground.png'));
  await sharp({create: {width:432,height:432,channels:4,
    background:'#0B1427'}}).png()
    .toFile(path.join(dest, 'v3-adaptive-background.png'));
  console.log('Generated local v3 PNG, Android adaptive, Windows/tray ICO assets');
}
main().catch(e => { console.error(e); process.exitCode=1; });
