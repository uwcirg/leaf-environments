# Leaf Environments
Configuration for Leaf sites

## Setup
Clone this repo to your desired location, including the --recurse-submodules argument to initialize all git submodules

    LEAF_CHECKOUT_PATH=$HOME/leaf-environments
    git clone --recurse-submodules https://github.com/uwcirg/leaf-environments $LEAF_CHECKOUT_PATH

### Prerequisites
- Traefik-based VM
- `git lfs`

### Configure
Copy `default.env` to `.env` and modify as necessary. Uncommented entries are required and may need to be provided if a default is empty or inappropriate.

    cp ${LEAF_CHECKOUT_PATH}/dev/default.env ${LEAF_CHECKOUT_PATH}/dev/.env

#### Generate a Signing Key
For each site, generate a JWT signing key. Follow Leaf instructions for [3 - Create a JWT Signing Key - Leaf Docs](https://leafdocs.rit.uw.edu/installation/installation_steps/3_jwt/) and save `cert.pem`, `key.pem` and `leaf.pfx` to `${LEAF_CHECKOUT_PATH}/dev/${SITE}/keys/`

    SITE=gateway
    openssl req -nodes -x509 -newkey rsa:2048 -days 3650 \
        -keyout ${LEAF_CHECKOUT_PATH}/dev/${SITE}/keys/key.pem \
        -out ${LEAF_CHECKOUT_PATH}/dev/${SITE}/keys/cert.pem \
        -subj "/CN=urn:leaf:issuer:leaf.${INSTITUTION:-cirg}.${TLD:-uw.edu}"

    openssl pkcs12 -export \
        -in ${LEAF_CHECKOUT_PATH}/dev/${SITE}/keys/cert.pem \
        -inkey ${LEAF_CHECKOUT_PATH}/dev/${SITE}/keys/key.pem \
        -out ${LEAF_CHECKOUT_PATH}/dev/${SITE}/keys/leaf.pfx \
        -password pass:${JWT_KEY_PW:-cirg-leaf}

## Deploy
Pull the latest docker images and start all containers

    docker compose pull
    docker compose up --detach

After 10+ minutes, Leaf should be available at `https://${LEAF_DOMAIN}`, or `https://${SITE}.${LEAF_DOMAIN}`. If any services fail to start, re-run `docker compose up --detach`

## Loading Clinical Data
To load a site-specific dataset into its corresponding database, invoke mysql as follows

    sql_file_path=/srv/www/leaf-scripts/cnics_data.phosphorus.2024.03.14.19.07.reduced.sql
    docker compose exec -T clin-db mysql --user=db-user --password=cnics@CIRG ${SITE} < $sql_file_path
