#!/usr/bin/env bash
# Copy etc/sysctl.d/*.conf into /etc/sysctl.d as real files (not symlinks),
# so systemd-sysctl can read them at early boot before /home is available.

set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo install -m 644 -t /etc/sysctl.d etc/sysctl.d/*.conf
