#!/usr/bin/env python3
"""
Generate /etc/hostapd/hostapd.conf from /opt/buoy/config/wifi.json.
Run as root. Called by wifi-ap-setup.service before hostapd starts.
"""
import json
import os

WIFI_JSON = "/opt/buoy/config/wifi.json"
HOSTAPD_CONF = "/etc/hostapd/hostapd.conf"

DEFAULTS = {
    "ssid": "Buoy",
    "passphrase": "ChangeMe",
    "interface": "wlan0",
    "country": "US",
    "channel": 6,
}

if not os.path.exists(WIFI_JSON):
    exit(0)

with open(WIFI_JSON) as f:
    cfg = {**DEFAULTS, **json.load(f)}

ssid = str(cfg.get("ssid", DEFAULTS["ssid"]))
passphrase = str(cfg.get("passphrase", DEFAULTS["passphrase"]))
interface = str(cfg.get("interface", DEFAULTS["interface"]))
country = str(cfg.get("country", DEFAULTS["country"]))
channel = int(cfg.get("channel", DEFAULTS["channel"]))

conf = f"""# Buoy – WiFi AP (generated from config)
interface={interface}
driver=nl80211
ssid={ssid}
channel={channel}
hw_mode=g
wpa=2
wpa_passphrase={passphrase}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
auth_algs=1
country_code={country}
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
"""

os.makedirs(os.path.dirname(HOSTAPD_CONF), exist_ok=True)
with open(HOSTAPD_CONF, "w") as f:
    f.write(conf)
os.chmod(HOSTAPD_CONF, 0o640)
