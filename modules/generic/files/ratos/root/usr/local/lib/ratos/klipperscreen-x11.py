#!/usr/bin/env python3
"""Select the Raspberry Pi display KMS card for KlipperScreen's Xorg server."""
import os
from pathlib import Path
import re
import sys


def select_card(drm_class=Path('/sys/class/drm'), dev_root=Path('/dev/dri')):
    candidates = set()
    connected = set()
    for status in sorted(drm_class.glob('card*-*/status')):
        match = re.match(r'(card[0-9]+)-', status.parent.name)
        if not match:
            continue
        card = dev_root / match[1]
        if not card.exists():
            continue
        candidates.add(card)
        if status.read_text().strip() == 'connected':
            connected.add(card)
    usable = connected or candidates
    if not usable:
        raise RuntimeError('No display KMS card found; check the display and vc4-kms-v3d')
    return sorted(usable, key=lambda p: int(p.name[4:]))[0]


def xorg_config(card):
    return f'''# Managed by RatOS: generated from the target display's DRM connectors.
Section "Device"
    Identifier "KlipperScreen"
    Driver "modesetting"
    Option "kmsdev" "{card}"
EndSection

Section "Screen"
    Identifier "KlipperScreenScreen"
    Device "KlipperScreen"
EndSection
'''


if __name__ == '__main__':
    if os.geteuid() != 0:
        sys.exit('Must run as root')
    try:
        card = select_card()
        config = Path('/etc/X11/xorg.conf.d/10-klipperscreen.conf')
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(xorg_config(card))
        print(f'KlipperScreen X11 display: {card}', flush=True)
    except (OSError, RuntimeError) as error:
        sys.exit(str(error))
