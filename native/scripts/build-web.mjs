// Copies the web app (from the repo root) into native/www for the iPhone build.
// The website on Netlify keeps serving the files at the repo root, unchanged.
import { cpSync, mkdirSync, rmSync } from 'node:fs';
rmSync('www', { recursive: true, force: true });
mkdirSync('www');
for (const f of ['index.html', 'sw.js', 'manifest.webmanifest', 'icons']) cpSync(`../${f}`, `www/${f}`, { recursive: true });
console.log('Copied the web app into native/www');
