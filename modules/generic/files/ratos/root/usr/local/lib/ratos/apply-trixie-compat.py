#!/usr/bin/env python3
"""Adapt the deployed RatOS 2.1.3 update scripts without changing Klipper pin."""
import os
from pathlib import Path
import pwd
import subprocess
import sys


def patch(repo):
    scripts = repo / 'configuration/scripts'
    common = scripts / 'ratos-common.sh'
    data = common.read_text().replace('libopenblas-base', 'libopenblas0')
    common.write_text(data)
    update = scripts / 'ratos-update.sh'
    data = update.read_text()
    old = 'if node -v | grep "^v18" > /dev/null; then'
    new = 'if [[ "$(node -p \'Number(process.versions.node.split(".")[0])\')" -ge 18 ]]; then'
    if old in data:
        data = data.replace(old, new)
    elif new not in data:
        raise RuntimeError('Unknown RatOS Node version check; compatibility needs review')
    update.write_text(data)
    req = repo / 'configuration/klippy/requirements.txt'
    data = req.read_text()
    if 'pygam==0.9.1\n' in data:
        data = data.replace('pygam==0.9.1\n', 'pygam==0.9.1; python_version < "3.13"\npygam==0.10.1; python_version >= "3.13"\n')
    req.write_text(data)


def install_components(repo):
    account = pwd.getpwuid(repo.stat().st_uid)
    home = Path(account.pw_dir)
    def run(args):
        subprocess.run(['runuser', '-u', account.pw_name, '--', *map(str, args)], check=True)
    python = home / 'klippy-env/bin/python'
    for name, url, expected in [
        ('beacon', 'https://github.com/beacon3d/beacon_klipper.git', 'beacon.py'),
        ('klipper_linear_movement_analysis', 'https://github.com/worksasintended/klipper_linear_movement_analysis.git', 'linear_movement_vibrations.py'),
    ]:
        dest = home / name
        if not dest.exists():
            run(['git', 'clone', '--depth', '1', url, dest])
        if not (dest / expected).is_file():
            raise RuntimeError(f'Incomplete extension repository: {dest}')
        req = dest / 'requirements.txt'
        if req.is_file():
            run([python, '-m', 'pip', 'install', '-r', req])
    run([python, '-m', 'pip', 'install', '-r', repo / 'configuration/klippy/requirements.txt', 'matplotlib'])
    run([python, '-c', 'from pygam import LinearGAM, s; import matplotlib; LinearGAM(s(0))'])


if __name__ == '__main__':
    if os.geteuid() != 0:
        sys.exit('Must run as root')
    repo = Path(sys.argv[1]).resolve()
    patch(repo)
    if '--install-components' in sys.argv[2:]:
        install_components(repo)
