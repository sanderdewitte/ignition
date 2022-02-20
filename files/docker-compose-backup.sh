#!/usr/bin/env bash

# fully backup a docker-compose project,
# including images, named/unnamed volumes,
# container filesystems, config and logs 

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
IFS=$'\n'

backup_day=$(date +"%u")
backup_time=$(date +"%y%m%dT%H%M")

project_dir="${1:-$PWD}"
project_name=$(basename "$project_dir")
if [ -f "$project_dir/docker-compose.yml" ]; then
  echo "[i] Found docker-compose config at $project_dir/docker-compose.yml"
else
  echo "[x] Could not find a docker-compose.yml file in $project_dir"
  exit 1
fi

data_dir="/var/opt/data"
backup_parent_dir="$data_dir/backups/$project_name"
backup_dir="$backup_parent_dir/$backup_time"

[ -f "$project_dir/docker-compose.env" ] && source "$project_dir/docker-compose.env"
[ -f "$project_dir/.env" ] && source "$project_dir/.env"

echo "[+] Backing up $project_name project to $backup_dir"
mkdir -p "$backup_dir"

echo "    - Saving docker-compose.yml config"
cp "$project_dir/docker-compose.yml" "$backup_dir/docker-compose.yml"

# optional: run a command inside the contianer to dump your application's state/database to a stable file
echo "    - Saving application state to ./dumps"
mkdir -p "$backup_dir/dumps"
# your database/stateful service export commands to run inside docker go here, e.g.
#   docker-compose exec postgres env PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip -9 > "$backup_dir/dumps/$POSTGRES_DB.sql.gz"
#   docker-compose exec redis redis-cli SAVE
#   docker-compose exec redis cat /data/dump.rdb | gzip -9 > "$backup_dir/dumps/redis.rdb.gz"

# optional: pause the containers before backing up to ensure consistency
# docker-compose pause

for service_name in $(docker-compose config --services); do

  image_id=$(docker-compose images -q "$service_name")
  image_name=$(docker image inspect --format '{{json .RepoTags}}' "$image_id" | jq -r '.[0]')
  container_id=$(docker-compose ps -q "$service_name")

  service_dir="$backup_dir/$service_name"
  echo "[*] Backing up Proj_${project_name}_Serv_${service_name} to ./$service_name"
  mkdir -p "$service_dir"
    
  # save image
  echo "    - Saving $image_name image to ./$service_name/image.tar"
  docker save --output "$service_dir/image.tar" "$image_id"
    
  if [[ -z "$container_id" ]]; then
    echo "    - Warning: $service_name has no container yet."
    echo "         (has it been started at least once?)"
    continue
  fi

  # save config
  echo "    - Saving container config to ./$service_name/config.json"
  docker inspect "$container_id" > "$service_dir/config.json"

  # save logs
  echo "    - Saving stdout/stderr logs to ./$service_name/docker.{out,err}"
  docker logs "$container_id" > "$service_dir/docker.out" 2> "$service_dir/docker.err"

  # save data volumes
  skip_volumes=("/var/run/docker.sock" "/sys" "/proc" "/data/backups")
  mkdir -p "$service_dir/volumes"
  for source in $(docker inspect -f '{{range .Mounts}}{{println .Source}}{{end}}' "$container_id"); do
    match=0 
    for skip_volume in "${skip_volumes[@]}"; do
      if [[ $skip_volume = "$source" ]]; then
        match=1
	break
      fi
    done
    if [[ $match = 0 ]]; then
      volume_dir="$service_dir/volumes$source"
      echo "    - Saving $source volume to ./$service_name/volumes$source"
      mkdir -p $(dirname "$volume_dir")
      cp -a -r "$source" "$volume_dir"
    fi
  done

  # save container filesystem
  echo "    - Saving container filesystem to ./$service_name/container.tar"
  docker export --output "$service_dir/container.tar" "$container_id"

  # save entire container root dir
  echo "    - Saving container root to ./$service_name/root"
  cp -a -r "/var/lib/docker/containers/$container_id" "$service_dir/root"

done

archive_name=${project_name}_container_backup_day${backup_day}.tgz 
[ -f "$backup_parent_dir/$archive_name" ] && rm -f "$backup_parent_dir/$archive_name"
echo "[*] Compressing backup folder to $archive_name"
tar -zcf "$backup_parent_dir/$archive_name" --totals -C "$backup_parent_dir" "$backup_time" && rm -Rf "$backup_dir"
retval=$?

if [ $retval -ne 0 ]; then
  echo "[x] Something went wrong backing up $project_name to $archive_name."
else
  [ -f "$backup_parent_dir/$archive_name" ] && chown ${CORE_USER_ID:-0}:${DOCKER_GROUP_ID:-0} "$backup_parent_dir/$archive_name" && chmod 0640 "$backup_parent_dir/$archive_name"
  echo "[√] Finished backing up $project_name to $archive_name."
fi

# resume the containers if paused above
# docker-compose unpause

exit 0
