#!/bin/bash

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

if [[ ! -f ./.env ]]; then
  echo ".env file does not exist on your filesystem."
  exit 1
fi

# Local .env
if [ -f .env ]; then
    # Load Environment Variables
    export $(cat .env | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
  echo "Settung up an email for letsencrypt certificates is strongly recommended."
  exit 1
fi

if [[ -z $DOMAIN_NAME ]]; then
  echo "DOMAIN_NAME env variable is not set in .env ."
  exit 1
fi


usage() {
  echo -e "Initializes letsencrypt certificates for Nginx proxy container\n"
  echo -e "Usage: $0 [-n|-r|-h]\n"
  echo "  -n|--non-interactive  Enable non interactive mode"
  echo "  -r|--replace          Replace existing certificates without asking"
  echo "  -h|--help             Show usage information"
  exit 1
}

interactive=1
replaceExisting=0

while [[ $# -gt 0 ]]
do
    case "$1" in
        -n|--non-interactive) interactive=0;shift;;
        -r|--replace) replaceExisting=1;shift;;
        -h|--help) usage;;
        -*) echo "Unknown option: \"$1\"\n";usage;;
        *) echo "Script does not accept arguments\n";usage;;
    esac
done

# Presetting the enviroment
echo "### Stopping Greenlight services..."
docker-compose down
echo

echo "### Preparing enviroment..."
IFS=' '
GL_HOSTNAME=${GL_HOSTNAME:-"gl"}
KC_HOSTNAME=${KC_HOSTNAME:-"kc"}
domains="$GL_HOSTNAME.$DOMAIN_NAME $KC_HOSTNAME.$DOMAIN_NAME"
domains=($domains)
rsa_key_size=4096
data_path="./data/certbot"
email="$LETSENCRYPT_EMAIL" # Adding a valid address is strongly recommended.
staging=${LETSENCRYPT_STAGING:-0}
echo

if [ -d "$data_path" ] && [ "$replaceExisting" -eq 0 ]; then
    if [ "$interactive" -eq 0 ]; then
      echo "Certificates already exist."
      exit
    fi

    read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
    if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
      exit
    fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Starting scalelite-proxy ..."
docker-compose up --force-recreate -d scalelite-proxy
echo

echo "### Requesting Let's Encrypt certificate for $domains ..."
### Preparing args:
# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then
  staging_arg="--staging"
  echo "-> Running in staging mode."
fi

docker-compose restart nginx

for domain in ${domains[@]}; do
  domain_args="-d '$domain'"
  echo "-> Requesting Let's Encrypt certificate for $domain ..."
  docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $([ "$interactive" -ne 1 ] && echo '--non-interactive') \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --debug-challenges \
    --force-renewal" certbot
  echo
done
echo

echo "### Reloading nginx..."
docker-compose exec $([ "$interactive" -ne 1 ] && echo "-T") nginx nginx -s reload

echo "### Stopping Greenlight services..."
docker-compose down