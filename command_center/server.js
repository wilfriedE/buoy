/**
 * Maser Buoy command center – serves dashboard and proxies device list API.
 * Connects to rosbridge at localhost:9090 for the frontend.
 */
const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.COMMAND_CENTER_PORT || 8080;

// DHCP leases path (RaspAP / dnsmasq)
const LEASES_PATH = process.env.DHCP_LEASES_PATH || '/var/lib/misc/dnsmasq.leases';

app.use(express.static(path.join(__dirname, 'public')));

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

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Maser Buoy command center at http://0.0.0.0:${PORT}`);
});
