#!/usr/bin/env bash

cat >/etc/sysconfig/coreos.env <<EOF
# Core user ID
CORE_USER_ID=$(getent passwd core | cut -d ':' -f 3)

# Docker group ID
DOCKER_GROUP_ID=$(getent group docker | cut -d ':' -f 3)

# Container user ID
CONTAINER_USER_ID=$(getent passwd | grep container-user | head -1 | cut -d ':' -f 3)

# Container group ID
CONTAINER_GROUP_ID=$(getent group | grep container-group | head -1 | cut -d ':' -f 3)

# Server domain name
SERVER_DOMAIN_NAME=${SERVER_DOMAIN_NAME}

# Server timezone
TZ=${TZ}
EOF

if [ ! -f /etc/sysconfig/coreos.env ]; then
  exit 1
fi

exit 0
