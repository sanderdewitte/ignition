#!/usr/bin/env bash
set -o nounset

# fully backup a docker compose project,
# including images, named/unnamed volumes,
# container filesystems, config and logs 

# configuration
PROJECT_DIR="${1:-$PWD}"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
DATA_DIR="/opt/data"
BACKUP_DIR="$DATA_DIR/backups"
PROJECT_BACKUP_DIR="$BACKUP_DIR/$PROJECT_NAME"
ONLY_ARCHIVE_BACKUP_WHEN_BACKUP_DIR_MOUNTED=1

# exit if not a docker compose project
if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
  echo "[i] Found docker compose config at $PROJECT_DIR/docker-compose.yml"
else
  echo "[x] Could not find a docker-compose.yml file in $PROJECT_DIR"
  exit 1
fi

# source environment variables
[ -f "$PROJECT_DIR/docker-compose.env" ] && source "$PROJECT_DIR/docker-compose.env"
[ -f "$PROJECT_DIR/.env" ] && source "$PROJECT_DIR/.env"

# timestamp
BACKUP_DAY=$(date +"%u")
BACKUP_TIME=$(date +"%y%m%dT%H%M")

# create temporary directory and define how to clean it
TMP_DATA_DIR=$(mktemp -d -p "$DATA_DIR")
function cleanup {
  [ -d "$TMP_DATA_DIR" ] && rm -Rf "$TMP_DATA_DIR"
}
trap cleanup EXIT
trap cleanup SIGINT

# create temporary backup directory
TMP_BACKUP_DIR="$TMP_DATA_DIR/$BACKUP_TIME"
mkdir -p "$TMP_BACKUP_DIR"
if [ -d "$TMP_BACKUP_DIR" ]; then
  echo "[+] Backing up $PROJECT_NAME to $TMP_BACKUP_DIR"
else
  echo "[x] Could not create temporary backup directory ($TMP_BACKUP_DIR) for $PROJECT_NAME backup"
  exit 1
fi

# backup docker-compose.yml
echo "    - Saving docker-compose.yml config"
cp "$PROJECT_DIR/docker-compose.yml" "$TMP_BACKUP_DIR/docker-compose.yml"

# run command inside container to dump application state/database to a stable file
echo "    - Saving application state to ./dumps"
DB_CONTAINERS=("nextcloud-mariadb" "nextcloud-redis")
mkdir -p "$TMP_BACKUP_DIR/dumps"
for DB_CONTAINER in "${DB_CONTAINERS[@]}"; do

  [[ $DB_CONTAINER != ${PROJECT_NAME}* ]] && continue

  unset ARCHIVE_NAME

  if [[ $DB_CONTAINER == *db ]]; then
    ARCHIVE_NAME=${PROJECT_NAME}_db_dump_day${BACKUP_DAY}.sql.gz
    SECRETS_FILE=secrets/${PROJECT_NAME}_db_root.secret
    if [ -f $SECRETS_FILE ]; then
      read -r HOST_DIR CONTAINER_DIR <<< $(docker inspect -f '{{range .Mounts}}{{if eq "volume" .Type}}{{println .Source .Destination}}{{end}}{{end}}' $DB_CONTAINER | head -1)
      echo -e "[mysqldump]\nuser=root\npassword=$(cat -- "$SECRETS_FILE")" > $HOST_DIR/.my.cnf
      if  [ -f $HOST_DIR/.my.cnf ]; then
        chmod 0600 $HOST_DIR/.my.cnf
        docker exec $DB_CONTAINER mysqldump --defaults-file=$CONTAINER_DIR/.my.cnf --skip-lock-tables --single-transaction --all-databases | gzip -9 > $TMP_BACKUP_DIR/dumps/$ARCHIVE_NAME
        rm -f $HOST_DIR/.my.cnf
      fi
    fi
  fi

  if [[ $DB_CONTAINER == *redis ]]; then
    ARCHIVE_NAME=${PROJECT_NAME}_redis_dump_day${BACKUP_DAY}.rdb.gz
    REDIS_DIR=/data
    REDIS_SAVE_RESULT=$(docker exec $DB_CONTAINER /usr/local/bin/redis-cli -e SAVE)
    if [[ "$REDIS_SAVE_RESULT" == "OK" ]]; then
      docker exec $DB_CONTAINER cat $REDIS_DIR/dump.rdb | gzip -9 > "$TMP_BACKUP_DIR/dumps/$ARCHIVE_NAME"
    fi
  fi

done

# optional: pause the containers before backing up to ensure consistency
# docker compose pause

for SERVICE_NAME in $(docker compose config --services 2>/dev/null); do

  IMAGE_ID=$(docker compose images -q "$SERVICE_NAME" 2>/dev/null)
  IMAGE_NAME=$(docker image inspect --format '{{json .RepoTags}}' "$IMAGE_ID" | jq -r '.[0]')
  CONTAINER_ID=$(docker compose ps -q "$SERVICE_NAME" 2>/dev/null)

  SERVICE_DIR="$TMP_BACKUP_DIR/$SERVICE_NAME"
  echo "[*] Backing up Proj_${PROJECT_NAME}_Serv_${SERVICE_NAME} to ./$SERVICE_NAME"
  mkdir -p "$SERVICE_DIR"
    
  # save image
  echo "    - Saving $IMAGE_NAME image to ./$SERVICE_NAME/image.tar"
  docker save --output "$SERVICE_DIR/image.tar" "$IMAGE_ID"
    
  if [[ -z "$CONTAINER_ID" ]]; then
    echo "    - Warning: $SERVICE_NAME has no container yet"
    echo "         (has it been started at least once?)"
    continue
  fi

  # save config
  echo "    - Saving container config to ./$SERVICE_NAME/config.json"
  docker inspect "$CONTAINER_ID" > "$SERVICE_DIR/config.json"

  # save logs
  echo "    - Saving stdout/stderr logs to ./$SERVICE_NAME/docker.{out,err}"
  docker logs "$CONTAINER_ID" > "$SERVICE_DIR/docker.out" 2> "$SERVICE_DIR/docker.err"

  # save data volumes
  SKIP_VOLUMES=("/sys" "/proc" "/var/run/docker.sock")
  if [ -n "${BACKUP_SKIP_VOLUMES:-}" ]; then
    SKIP_VOLUMES+=("${BACKUP_SKIP_VOLUMES[@]}")
  fi
  mkdir -p "$SERVICE_DIR/volumes"
  for SOURCE in $(docker inspect -f '{{range .Mounts}}{{println .Source}}{{end}}' "$CONTAINER_ID"); do
    [[ $SOURCE == *.secret ]] && continue
    SKIP=0 
    for SKIP_VOLUME in "${SKIP_VOLUMES[@]}"; do
      if [[ "$SOURCE" = "$SKIP_VOLUME" ]]; then
        SKIP=1
	break
      fi
    done
    if [[ $SKIP = 0 ]]; then
      VOLUME_DIR="$SERVICE_DIR/volumes$SOURCE"
      echo "    - Saving $SOURCE volume to ./$SERVICE_NAME/volumes$SOURCE"
      mkdir -p $(dirname "$VOLUME_DIR")
      cp -a -r "$SOURCE" "$VOLUME_DIR"
    fi
  done

  # save container filesystem
  echo "    - Saving container filesystem to ./$SERVICE_NAME/container.tar"
  docker export --output "$SERVICE_DIR/container.tar" "$CONTAINER_ID"

  # save entire container root dir
  echo "    - Saving container root to ./$SERVICE_NAME/root"
  cp -a -r "/var/lib/docker/containers/$CONTAINER_ID" "$SERVICE_DIR/root"

done

# optional: resume the containers if paused above
# docker compose unpause

# archive backup
ARCHIVE_RETVAL=1
ARCHIVE_NAME=${PROJECT_NAME}_container_backup_day${BACKUP_DAY}.tgz 
if [ $ONLY_ARCHIVE_BACKUP_WHEN_BACKUP_DIR_MOUNTED -eq 0 ] || mountpoint -q "$BACKUP_DIR"; then
  if [ -d "$PROJECT_BACKUP_DIR" ]; then
    [ -f "$PROJECT_BACKUP_DIR/$ARCHIVE_NAME" ] && rm -f "$PROJECT_BACKUP_DIR/$ARCHIVE_NAME"
  else
    mkdir -p "$PROJECT_BACKUP_DIR"
  fi
  if [ -d "$PROJECT_BACKUP_DIR" ]; then
    echo "[*] Compressing temporary backup folder to $ARCHIVE_NAME"
    tar -zcf "$PROJECT_BACKUP_DIR/$ARCHIVE_NAME" --totals -C "$TMP_DATA_DIR" "$BACKUP_TIME"
    ARCHIVE_RETVAL=$?
  else
    echo "[x] $PROJECT_NAME backup dir (to archive backup) does not exist and could not be created"
  fi
fi 

# change owner/mode of archive
if [ $ARCHIVE_RETVAL -eq 0 ]; then
  [ -f "$PROJECT_BACKUP_DIR/$ARCHIVE_NAME" ] && chown ${CONTAINER_USER_ID:-0}:${CONTAINER_GROUP_ID:-0} "$PROJECT_BACKUP_DIR/$ARCHIVE_NAME" && chmod 0640 "$PROJECT_BACKUP_DIR/$ARCHIVE_NAME"
else
  echo "[x] Something went wrong archiving backup for $PROJECT_NAME to $ARCHIVE_NAME"
fi

# exit gracefully
if [ $ARCHIVE_RETVAL -eq 0 ]; then
  echo "[√] Finished backing up $PROJECT_NAME successfully"
else
  echo "[x] Finished backing up $PROJECT_NAME with errors"
fi
exit $ARCHIVE_RETVAL
