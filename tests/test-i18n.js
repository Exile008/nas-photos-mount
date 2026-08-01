#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'web', 'index.html'), 'utf8');
const scriptMatch = html.match(/<script>\s*([\s\S]*?)<\/script>\s*<\/body>/);

if (!scriptMatch) throw new Error('inline application script not found');
new Function(scriptMatch[1]);

const messagesMatch = scriptMatch[1].match(/const messages = (\{[\s\S]*?\n    \});\n\n    const getInitialLanguage/);
if (!messagesMatch) throw new Error('translation dictionary not found');

const messages = new Function(`"use strict"; return (${messagesMatch[1]});`)();
const zhKeys = Object.keys(messages.zh).sort();
const enKeys = Object.keys(messages.en).sort();

if (JSON.stringify(zhKeys) !== JSON.stringify(enKeys)) {
  const missingEnglish = zhKeys.filter((key) => !enKeys.includes(key));
  const missingChinese = enKeys.filter((key) => !zhKeys.includes(key));
  throw new Error(`translation keys differ; missing EN: ${missingEnglish.join(', ')}; missing ZH: ${missingChinese.join(', ')}`);
}

const referencedKeys = new Set();
for (const match of html.matchAll(/data-i18n(?:-title|-placeholder|-aria)?="([^"]+)"/g)) referencedKeys.add(match[1]);
for (const match of scriptMatch[1].matchAll(/\bt\('([^']+)'/g)) referencedKeys.add(match[1]);
for (const match of scriptMatch[1].matchAll(/\btCount\('([^']+)'/g)) {
  referencedKeys.add(`${match[1]}.one`);
  referencedKeys.add(`${match[1]}.other`);
}

[
  'showPassword', 'hidePassword',
  'apiSmbLoginFailed', 'apiInvalidRemotePath', 'apiInvalidAlbumName', 'apiDuplicateAlbumName',
  'apiRemoteFilterFailed', 'apiBrowseFailed', 'apiSourceLimit',
  'scanStarted', 'remountingSource', 'pausingMount', 'resumingMount', 'refreshingCapacity', 'remountingAll',
].forEach((key) => referencedKeys.add(key));

const missingKeys = [...referencedKeys].filter((key) => !(key in messages.zh));
if (missingKeys.length) throw new Error(`missing translation keys: ${missingKeys.join(', ')}`);

for (const file of ['README_EN.md', 'CONFIG_EN.md']) {
  if (!fs.existsSync(path.join(root, file))) throw new Error(`${file} is missing`);
}

console.log(`i18n test passed (${zhKeys.length} keys)`);
