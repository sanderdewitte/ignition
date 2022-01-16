#!/usr/bin/env bash

cat >/etc/sysconfig/coreos-env <<EOF
# Docker group ID (used by netdata)
DOCKER_GROUP_ID=$(id -g docker)

# Server domain namee
SERVER_DOMAIN_NAME=${SERVER_DOMAIN_NAME}
EOF
