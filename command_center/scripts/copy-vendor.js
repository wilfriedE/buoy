#!/usr/bin/env node
/**
 * Copy vendor JS (roslib, vis-network) to public/vendor for offline use.
 * Fetches from CDN during build so the Pi can serve them without internet.
 */
const fs = require('fs');
const path = require('path');
const https = require('https');

const VENDOR_DIR = path.join(__dirname, '..', 'public', 'vendor');
const VENDORS = [
  {
    name: 'roslib.min.js',
    url: 'https://cdn.jsdelivr.net/npm/roslib@1/build/roslib.min.js',
  },
  {
    name: 'vis-network.min.js',
    url: 'https://unpkg.com/vis-network@9.1.2/standalone/umd/vis-network.min.js',
  },
  {
    name: 'mermaid.min.js',
    url: 'https://cdn.jsdelivr.net/npm/mermaid@9/dist/mermaid.min.js',
  },
];

function fetch(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`${url} returned ${res.statusCode}`));
        return;
      }
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

async function main() {
  fs.mkdirSync(VENDOR_DIR, { recursive: true });
  for (const v of VENDORS) {
    const dest = path.join(VENDOR_DIR, v.name);
    console.log(`Fetching ${v.name}...`);
    const buf = await fetch(v.url);
    fs.writeFileSync(dest, buf);
    console.log(`  -> ${dest}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
