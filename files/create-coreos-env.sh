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

# Server timezone
TZ=${TZ}

# Server domain name
SERVER_DOMAIN_NAME=${SERVER_DOMAIN_NAME}
EOF

# Initialize a variable to hold additional domain names
ADDITIONAL_DOMAIN_NAMES=""

# Loop through potential additional domain names
for i in $(seq -w 1 99); do
  VAR_NAME="ADDITIONAL_DOMAIN_NAME_$i"
  VAR_VALUE=${!VAR_NAME}
  if [ -n "$VAR_VALUE" ]; then
    ADDITIONAL_DOMAIN_NAMES+="${VAR_NAME}=${VAR_VALUE}\n"
  fi
done

# Append ADDITIONAL_DOMAIN_NAMES (if any)
if [ -n "$ADDITIONAL_DOMAIN_NAMES" ]; then
  echo -e "\n# Additional domain name(s)\n$ADDITIONAL_DOMAIN_NAMES" >> /etc/sysconfig/coreos.env
fi

if [ ! -f /etc/sysconfig/coreos.env ]; then
  exit 1
fi

exit 0
