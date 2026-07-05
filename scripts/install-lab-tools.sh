#!/usr/bin/env bash
#
# Install the tooling Protocol Lab needs on Ubuntu/Debian:
#   docker, containerlab, tshark, tcpdump, jq, curl.
#
# Usage:
#   sudo bash scripts/install-lab-tools.sh          # install everything
#   sudo bash scripts/install-lab-tools.sh --pull   # also pre-pull lab images
#
# After it finishes, log out and back in (or run `newgrp docker`) so the
# docker group membership takes effect, then check with:
#   ./scripts/labctl.sh doctor tcp-07
#
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root:  sudo bash $0 $*" >&2
  exit 1
fi

PULL_IMAGES="no"
[[ "${1:-}" == "--pull" ]] && PULL_IMAGES="yes"

# The non-root user to add to the docker / wireshark groups.
TARGET_USER="${SUDO_USER:-${TARGET_USER:-}}"

export DEBIAN_FRONTEND=noninteractive

echo "[1/6] apt-get update"
apt-get update -y

echo "[2/6] installing base tools (docker.io, tshark, tcpdump, jq, curl)"
# Preseed so tshark installs dumpcap setuid and non-root capture works.
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
apt-get install -y --no-install-recommends \
  docker.io tshark tcpdump jq curl ca-certificates iproute2

echo "[3/6] installing containerlab"
if command -v containerlab >/dev/null 2>&1; then
  echo "  containerlab already present: $(containerlab version 2>/dev/null | awk '/version:/{print $2}' | head -1)"
else
  # Official installer: adds the containerlab apt repo and installs the .deb.
  curl -sL https://get.containerlab.dev | bash
fi

echo "[4/6] enabling the docker service"
systemctl enable --now docker || service docker start || true

echo "[5/6] group membership"
if [[ -n "${TARGET_USER}" ]]; then
  usermod -aG docker "${TARGET_USER}" || true
  if getent group wireshark >/dev/null; then
    usermod -aG wireshark "${TARGET_USER}" || true
  fi
  echo "  added ${TARGET_USER} to the docker (and wireshark) group(s)"
else
  echo "  no SUDO_USER detected; add your user to the docker group manually:"
  echo "    sudo usermod -aG docker <you>"
fi

echo "[6/6] versions"
docker --version || true
containerlab version 2>/dev/null | head -3 || true
tshark --version 2>/dev/null | head -1 || true

if [[ "${PULL_IMAGES}" == "yes" ]]; then
  echo
  echo "Pre-pulling lab base images (this can take a while)..."
  for img in \
    nicolaka/netshoot:latest \
    internetsystemsconsortium/bind9:9.20 \
    caddy:2 \
    frrouting/frr:latest \
    rpki/stayrtr:latest; do
    echo "  docker pull ${img}"
    docker pull "${img}" || echo "  (failed to pull ${img}; run.sh will retry)"
  done
fi

echo
echo "Done."
echo "IMPORTANT: log out and back in (or run 'newgrp docker') so docker group access applies,"
echo "then verify with:  ./scripts/labctl.sh doctor tcp-07"
