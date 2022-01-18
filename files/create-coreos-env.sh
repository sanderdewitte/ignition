#!/usr/bin/env bash

cat >/etc/sysconfig/coreos-env <<EOF
# Docker group ID (used by netdata container)
DOCKER_GROUP_ID=$(getent group docker | cut -d ':' -f 3)

# Server domain name (used by all containers)
SERVER_DOMAIN_NAME=${SERVER_DOMAIN_NAME}
EOF

if [ ! -f /etc/sysconfig/coreos-env ]; then
  exit 1
fi

exit 0
