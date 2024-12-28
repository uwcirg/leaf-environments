# Leaf Environments
Configuration for Leaf sites

## Setup
Clone this repo to your desired location, including the `--recurse-submodules` argument to initialize all git submodules

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
        -subj "/CN=urn:leaf:issuer:${SITE}.leaf.${INSTITUTION:-cirg}.${TLD:-uw.edu}"

    # load docker compose environment variables into current shell
    source .env

    JWT_KEY_PW="${SITE^^}_JWT_KEY_PW"
    openssl pkcs12 -export \
        -in ${LEAF_CHECKOUT_PATH}/dev/${SITE}/keys/cert.pem \
        -inkey ${LEAF_CHECKOUT_PATH}/dev/${SITE}/keys/key.pem \
        -out ${LEAF_CHECKOUT_PATH}/dev/${SITE}/keys/leaf.pfx \
        -password pass:${!JWT_KEY_PW}

Keys need to be readable by the API container. To make all keys readable, run the command below

    chmod -R o+r ${LEAF_CHECKOUT_PATH}/dev/*/keys

## Deploy
Pull the latest docker images and start all containers

    docker compose pull
    docker compose up --detach

After 10+ minutes, Leaf should be available at `https://${LEAF_DOMAIN}`, or `https://${SITE}.${LEAF_DOMAIN}`. If any services fail to start, re-run `docker compose up --detach`

## Loading Clinical Data
To load a site-specific dataset into its corresponding database, invoke mysql as follows (manually replacing ${SITE} with the desired site)

    sql_file_path=/srv/www/leaf-scripts/cnics_data.phosphorus.2024.03.14.19.07.reduced.sql
    docker compose exec -T clin-db bash -c 'mysql --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${SITE}' < $sql_file_path

## Troubleshooting Federated Instances
If trusted instances do not appear to be available for queries, and investigating the GET requests sent out by the gateway instance suggests calls to `/api/network/identity` on other instances are failing with a 401 error, then the following steps may be required to re-establish a working trust between instances.

1. Generate a new JWT signing key for the gateway instance, delete the old one (making sure issuer is identical to appsettings.json file).
2. Delete all records in the network.endpoint table for gateway and all other federated instances.
3. Restart the gateway container (ensure that it can read newly created signing key).
4. Reload and exchange signing keys again by re-establishing trusts between instances (all instances must permit queries from the gateway also).
5. Restart ALL containers.
6. Clear browser cache. Attempt a federated query.
