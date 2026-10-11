#!/usr/bin/env python3
"""RatOS legacy Wi-Fi arguments -> NetworkManager WPA2 profile."""
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid


def configure(args, profile_dir=Path('/etc/NetworkManager/system-connections'),
              regdomain_file=Path('/etc/modprobe.d/cfg80211.conf'), run=subprocess.run):
    if len(args) != 5:
        raise ValueError('Expected SSID, passphrase, country, frequencies, hidden/shown')
    ssid, password, country, frequencies, visibility = args
    if not 1 <= len(ssid.encode()) <= 32 or not 8 <= len(password) <= 63:
        raise ValueError('Invalid SSID or WPA passphrase length')
    if not re.fullmatch('[A-Z]{2}', country) or visibility not in ('hidden', 'shown'):
        raise ValueError('Invalid country or visibility')
    freqs = [int(f) for f in frequencies.split()]
    band = 'bg' if freqs and all(2400 <= f <= 2500 for f in freqs) else (
        'a' if freqs and all(4900 <= f <= 5900 for f in freqs) else None)
    # Hex SSID avoids keyfile escaping problems for spaces, semicolons and Unicode.
    ssid_bytes = ';'.join(str(b) for b in ssid.encode()) + ';'
    psk = hashlib.pbkdf2_hmac('sha1', password.encode(), ssid.encode(), 4096, 32).hex()
    profile_dir.mkdir(parents=True, exist_ok=True)
    path = profile_dir / 'ratos-wifi.nmconnection'
    existing = path.read_text() if path.exists() else ''
    match = re.search(r'^uuid=(.*)$', existing, re.M)
    ident = match[1] if match else str(uuid.uuid4())
    profile = (f'[connection]\nid=RatOS WiFi\nuuid={ident}\ntype=wifi\nautoconnect=true\n'
               'autoconnect-priority=100\n\n[wifi]\nmode=infrastructure\n'
               f'ssid={ssid_bytes}\nhidden={str(visibility == "hidden").lower()}\n'
               + (f'band={band}\n' if band else '')
               + f'\n[wifi-security]\nkey-mgmt=wpa-psk\npsk={psk}\n'
               '\n[ipv4]\nmethod=auto\n\n[ipv6]\nmethod=auto\n')
    tmp = path.with_suffix('.tmp')
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as out:
        out.write(profile)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)
    regdomain_file.parent.mkdir(parents=True, exist_ok=True)
    regdomain_file.write_text(f'options cfg80211 ieee80211_regdom={country}\n')
    run(['iw', 'reg', 'set', country], check=True, capture_output=True)
    run(['nmcli', 'connection', 'load', str(path)], check=True, capture_output=True)
    run(['nmcli', '--wait', '30', 'connection', 'up', 'uuid', ident], check=True,
        capture_output=True)


if __name__ == '__main__':
    if os.geteuid() != 0:
        sys.exit('This script must run as root')
    try:
        configure(sys.argv[1:])
    except (ValueError, OSError, subprocess.CalledProcessError):
        # Do not echo credentials or command output into configurator logs.
        sys.exit('Unable to configure Wi-Fi using NetworkManager')
