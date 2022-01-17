#!/usr/bin/env bash

cat >/etc/sysconfig/coreos-env <<EOF
# Docker group ID (used by netdata container)
DOCKER_GROUP_ID=$(getent group docker | cut -d ':' -f 3)

# Server domain name (used by all containers)
SERVER_DOMAIN_NAME=${SERVER_DOMAIN_NAME}

# Vultr API key file location (used by traefik container)
VULTR_API_KEY_FILE=/root/.secret/vultr_api.key
EOF

if [ ! -f /etc/sysconfig/coreos-env ]; then
  exit 1
fi

exit 0
