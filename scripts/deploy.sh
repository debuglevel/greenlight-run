#!/bin/bash

if ! [ -x "$(command -v docker compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPT_PATH=$(dirname "$SCRIPT")

if [[ ! -f $SCRIPT_PATH/../.env ]]; then
  echo ".env file does not exist on your filesystem."
  exit 1
fi

# Load Environment Variables
export $(cat $SCRIPT_PATH/../.env | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )

DOCKER_IMAGE=${GREENLIGHT_DOCKER_IMAGE:-bigbluebutton/greenlight:v3}

STATUS="Status: Downloaded newer image for $DOCKER_IMAGE"
NEW_STATUS=$(docker pull $DOCKER_IMAGE | grep Status:)

if [[ ! -e /var/log/greenlight-deploy.log ]]; then
  mkdir -p /var/log/
  touch /var/log/greenlight-deploy.log
fi
echo "Pulled on: $(date), $NEW_STATUS" >> /var/log/greenlight-deploy.log

if [ "$STATUS" != "$NEW_STATUS" ]; then
  exit 0
fi

cd $SCRIPT_PATH/..
docker compose down

# Remove dangling images if any
DOCKER_DANGLING_IMAGES=$(docker images -f dangling=true -q)
if [[ ! -z "$DOCKER_DANGLING_IMAGES" ]]; then
  docker rmi $DOCKER_DANGLING_IMAGES
fi

docker compose up -d
