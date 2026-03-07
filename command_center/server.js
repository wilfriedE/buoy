/**
 * Buoy command center – serves dashboard and proxies device list API.
 * Connects to rosbridge at localhost:9090 for the frontend.
 * Proxies /api/llm to Ollama when LLM variant is deployed.
 */
const express = require('express');
const http = require('http');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');
const { marked } = require('marked');

const app = express();
const PORT = process.env.COMMAND_CENTER_PORT || 8080;
const BUOY_ROOT = process.env.BUOY_ROOT || '/opt/buoy';
const WIFI_CONFIG_PATH = path.join(BUOY_ROOT, 'config', 'wifi.json');
const GENERATE_HOSTAPD_SCRIPT = path.join(BUOY_ROOT, 'config', 'generate-hostapd-conf.py');

// DHCP leases path (dnsmasq)
const LEASES_PATH = process.env.DHCP_LEASES_PATH || '/var/lib/misc/dnsmasq.leases';

// Proxy /api/llm to Ollama – must be before body parsers so we can stream
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';

// LLM status check (before proxy so we can short-circuit)
app.get('/api/llm/status', (req, res) => {
  try {
    const u = new URL('/api/tags', OLLAMA_URL);
    const opts = { hostname: u.hostname, port: u.port || (u.protocol === 'https:' ? 443 : 80), path: u.pathname, method: 'GET' };
    let sent = false;
    const send = (available) => {
      if (!sent) { sent = true; res.json({ available }); }
    };
    const statusReq = http.request(opts, (statusRes) => { send(statusRes.statusCode === 200); });
    statusReq.on('error', () => send(false));
    statusReq.setTimeout(3000, () => { statusReq.destroy(); send(false); });
    statusReq.end();
  } catch (err) {
    console.error('LLM status error:', err.message);
    res.json({ available: false });
  }
});

app.use('/api/llm', express.raw({ type: () => true }), (req, res) => {
  const reqPath = req.path === '/' ? '' : req.path;
  const target = new URL(reqPath + (req.url.includes('?') ? req.url.slice(req.url.indexOf('?')) : ''), OLLAMA_URL);
  const opts = {
    hostname: target.hostname,
    port: target.port || 80,
    path: target.pathname + target.search,
    method: req.method,
    headers: { ...req.headers, host: target.host },
  };
  delete opts.headers['host'];
  opts.headers['Host'] = target.host;
  const proxyReq = http.request(opts, (proxyRes) => {
    res.status(proxyRes.statusCode);
    Object.keys(proxyRes.headers).forEach((k) => res.setHeader(k, proxyRes.headers[k]));
    proxyRes.pipe(res);
  });
  proxyReq.on('error', (err) => {
    console.error('LLM proxy error:', err.message);
    res.status(503).json({ error: 'LLM service not available' });
  });
  if (req.body && Buffer.isBuffer(req.body)) {
    proxyReq.write(req.body);
  }
  proxyReq.end();
});

// JSON body parsing for POST
app.use(express.json());

const DOCS_DIR = path.join(__dirname, 'public', 'docs');

// Markdown docs rendered as HTML (must be before static)
app.get('/docs/:name.md', (req, res) => {
  try {
    const name = req.params.name.replace(/[^a-zA-Z0-9_-]/g, '');
    const filePath = path.join(DOCS_DIR, name + '.md');
    const resolved = path.resolve(filePath);
    const docsResolved = path.resolve(DOCS_DIR);
    const isUnderDocs = resolved === docsResolved || resolved.startsWith(docsResolved + path.sep);
    if (isUnderDocs && fs.existsSync(filePath)) {
      const md = fs.readFileSync(filePath, 'utf8');
      let html = marked.parse(md, { async: false });
      // Convert mermaid code blocks to div.mermaid for client-side rendering
      html = html.replace(/<pre><code class="language-mermaid">([\s\S]*?)<\/code><\/pre>/gi, '<div class="mermaid">$1</div>');
      const title = (html.match(/<h1[^>]*>([^<]+)<\/h1>/) || [null, name])[1] || name;
    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)} – Buoy</title>
  <link rel="icon" type="image/svg+xml" href="/logo.svg" />
  <link rel="stylesheet" href="/dist/tailwind.css" />
  <style>
    body { background: #0f172a; }
    .nav-link:hover { color: #38bdf8; }
    .doc-content h1 { font-size: 1.75rem; margin-top: 0; border-bottom: 1px solid #334155; padding-bottom: 0.5rem; }
    .doc-content h2 { font-size: 1.25rem; margin-top: 2rem; color: #38bdf8; }
    .doc-content h3 { font-size: 1.1rem; margin-top: 1.5rem; }
    .doc-content p { margin: 1rem 0; }
    .doc-content ul, .doc-content ol { margin: 1rem 0; padding-left: 1.5rem; }
    .doc-content li { margin: 0.25rem 0; }
    .doc-content code { background: #1e293b; padding: 0.15rem 0.4rem; border-radius: 6px; font-size: 0.9em; }
    .doc-content pre { background: #1e293b; padding: 1rem; border-radius: 8px; overflow-x: auto; border: 1px solid #334155; }
    .doc-content pre code { background: none; padding: 0; }
    .doc-content hr { border: none; border-top: 1px solid #334155; margin: 2rem 0; }
    .doc-content a { color: #38bdf8; }
    .doc-content strong { color: #f8fafc; }
    .doc-content .mermaid { margin: 1.5rem 0; display: flex; justify-content: center; }
  </style>
</head>
<body class="min-h-screen text-slate-200">
  <nav class="border-b border-slate-700/50 bg-slate-900/50 backdrop-blur">
    <div class="max-w-4xl mx-auto px-4 py-3 flex flex-wrap items-center justify-between gap-4">
      <div class="flex items-center gap-3">
        <a href="/" class="flex items-center gap-3">
          <img src="/logo.svg" alt="Buoy" class="w-8 h-8" />
          <span class="text-lg font-semibold text-white">Docs</span>
        </a>
      </div>
      <div class="flex items-center gap-4">
        <a href="/" class="nav-link text-sm text-slate-400">Dashboard</a>
        <a href="/ros-try.html" class="nav-link text-sm text-slate-400">Listen & Publish</a>
        <a href="/ros-graph.html" class="nav-link text-sm text-slate-400">Topic Graph</a>
        <a href="/sandbox/" class="nav-link text-sm text-slate-400">Sandbox</a>
      </div>
    </div>
  </nav>
  <main class="max-w-3xl mx-auto px-4 py-8">
    <div class="doc-content content">${html}</div>
  </main>
  <script src="/vendor/mermaid.min.js"></script>
  <script>mermaid.initialize({startOnLoad:true,theme:'dark',themeVariables:{primaryColor:'#0ea5e9',primaryTextColor:'#e2e8f0',primaryBorderColor:'#334155',lineColor:'#64748b',secondaryColor:'#1e293b',tertiaryColor:'#0f172a'}});</script>
</body>
</html>`);
    } else {
      res.status(404).send('Not found');
    }
  } catch (err) {
    console.error('Docs error:', err.message);
    res.status(500).send('Error loading document');
  }
});

function escapeHtml(s) {
  if (s == null) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Catch unhandled errors to log before exit (systemd will restart)
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
  process.exit(1);
});
process.on('unhandledRejection', (reason, p) => {
  console.error('Unhandled rejection at', p, 'reason:', reason);
});

app.use(express.static(path.join(__dirname, 'public')));

// API: WiFi config (GET current, POST to update)
app.get('/api/wifi', (req, res) => {
  try {
    if (fs.existsSync(WIFI_CONFIG_PATH)) {
      const data = JSON.parse(fs.readFileSync(WIFI_CONFIG_PATH, 'utf8'));
      res.json({ ssid: data.ssid || '', passphrase: '' }); // Never send passphrase to client
    } else {
      res.json({ ssid: '', passphrase: '' });
    }
  } catch (err) {
    console.error('Error reading WiFi config:', err.message);
    res.status(500).json({ error: 'Failed to read WiFi config' });
  }
});

app.post('/api/wifi', (req, res) => {
  const { ssid, passphrase } = req.body || {};
  if (typeof ssid !== 'string' || ssid.trim().length === 0) {
    res.status(400).json({ error: 'SSID is required' });
    return;
  }
  if (typeof passphrase === 'string' && passphrase.length > 0 && (passphrase.length < 8 || passphrase.length > 63)) {
    res.status(400).json({ error: 'Password must be 8–63 characters' });
    return;
  }
  try {
    let data = {};
    if (fs.existsSync(WIFI_CONFIG_PATH)) {
      data = JSON.parse(fs.readFileSync(WIFI_CONFIG_PATH, 'utf8'));
    }
    data.ssid = ssid.trim();
    if (typeof passphrase === 'string' && passphrase.length > 0) {
      data.passphrase = passphrase;
    }
    fs.writeFileSync(WIFI_CONFIG_PATH, JSON.stringify(data, null, 2), 'utf8');
    execSync(GENERATE_HOSTAPD_SCRIPT, { stdio: 'inherit' });
    execSync('systemctl restart hostapd', { stdio: 'inherit' });
    res.json({ success: true, ssid: data.ssid });
  } catch (err) {
    console.error('Error updating WiFi:', err.message);
    res.status(500).json({ error: 'Failed to update WiFi: ' + err.message });
  }
});

// API: connected devices from DHCP leases
app.get('/api/devices', (req, res) => {
  const devices = [];
  try {
    if (fs.existsSync(LEASES_PATH)) {
      const content = fs.readFileSync(LEASES_PATH, 'utf8');
      content.split('\n').forEach((line) => {
        const parts = line.trim().split(/\s+/);
        if (parts.length >= 4) {
          devices.push({
            mac: parts[1],
            ip: parts[2],
            hostname: parts[3] || parts[2],
            expiry: parts[0] ? parseInt(parts[0], 10) : null,
          });
        }
      });
    }
  } catch (err) {
    console.error('Error reading leases:', err.message);
  }
  res.json({ devices });
});

// Dashboard
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Express error handler (catches errors from async route handlers)
app.use((err, req, res, next) => {
  console.error('Route error:', err.message);
  res.status(500).send('Internal server error');
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Buoy command center at http://0.0.0.0:${PORT}`);
});
