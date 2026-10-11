#!/usr/bin/env python3
"""Reapply the pinned RatOS network adapter after configurator updates."""
from pathlib import Path
import os
import pwd
import re
import sys

if os.geteuid() != 0:
    sys.exit('Must run as root')
repo = Path(sys.argv[1]).resolve()
owner = pwd.getpwuid(repo.stat().st_uid).pw_name
script = repo / 'app/scripts/add-wifi-network.sh'
script.unlink(missing_ok=True)
script.symlink_to('/usr/local/lib/ratos/add-wifi-network.sh')
# v2.1.3 ships the Next.js build. Adapt only its legacy status command.
wizard = repo / 'app/build/server/app/wizard/page.js'
old = 'sudo wpa_cli -i "${e}" status | grep \'ip_address\''
new = 'sudo /usr/local/lib/ratos/wifi-status.sh "${e}"'
data = wizard.read_text()
if data.count(old) == 1:
    wizard.write_text(data.replace(old, new))
elif new not in data:
    sys.exit('Unknown configurator Wi-Fi status implementation; adapter requires review')
# Root owns this helper; whitelist just this operation for the service account.
if not re.fullmatch(r'[a-z_][a-z0-9_-]*', owner):
    sys.exit('Invalid service account')
Path('/etc/sudoers.d/032-ratos-networkmanager').write_text(
    f'{owner} ALL=(root) NOPASSWD: /usr/local/lib/ratos/wifi-status.sh\n')
os.chmod('/etc/sudoers.d/032-ratos-networkmanager', 0o440)
