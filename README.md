# greenlight-run
A simple way to do a standalone deployment of Greenlight for development or production using docker-compose.

## Installation for devlopment (short version)

On an Ubuntu 20.04 machine (AWS EC2 instance, LXC container, VMWare machine etc).

### Fetching the scripts

```
git clone https://github.com/jfederico/greenlight-run
cd greenlight-run
git checkout dev-v3
```

### Initializing environment variables
Create a new .env file for greenlight based on the dotenv file included.

```
cp data/greenlight/dotenv data/greenlight/.env
```

Most required variables are pre-set by default, the ones that must be set before starting are:

```
SECRET_KEY_BASE=
PORT=
```

They can be added by editing the file or with sed.

```
sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$(openssl rand -hex 64)/" data/greenlight/.env
sed -i "s/PORT=.*/PORT=3080/" data/greenlight/.env
```


Create a new .env file for the deployment based on the dotenv file included.

```
cp dotenv .env
```

The only variable required is the domain name that will be used, since by default, the app will be exposed as gl.DOMAIN_NAME for greenlight and kc.DOMAIN_NAME for keycloak.
```
DOMAIN_NAME=
```

Also, when using the `init-letsencrypt.sh` script, you should add the email.

```
LETSENCRYPT_EMAIL=
```

For using a SSL certificate signed by Let’s Encrypt, generate the certificates.

Manual


Automated (on machines on the cloud holding a public IP and linked to a valid hostname)
```
./init-letsencrypt.sh
```

Start the services.

docker-compose up -d

Now, the greenlight server is running, but it is not quite yet ready. The database must be initialized.

For greenlight:
```
docker exec -i greenlight bundle exec rake db:setup
```

For keycloak:
```
docker exec -it postgres psql -U postgres -W
password
CREATE DATABASE keycloakdb
Ctrl-d
```

For development, we can use the local template by editing the variable `SITES_TEMPLATE=local` in `.env`. This will redirect the requests to your local rails app instead of doing so to the docker container.

Keep in mind that the port in the template is hard-coded to `3000`, but it can be edited (or sed)  directly at `data/nginx/sites.template-local`.

E.g.
```
sed -i "s/NGINX_HOSTNAME:.*/NGINX_HOSTNAME:5000/" data/nginx/sites.template-local
```

When keycloak is initialized, it also needs to be configured by adding a, and then set those values into the `data/greenlight/.env` file.
