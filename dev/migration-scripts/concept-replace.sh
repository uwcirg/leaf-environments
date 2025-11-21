#!/bin/bash

# Throw an error if no argument is passed -- the correct syntax is
#   concept-replace.sh <docker-service-name>

if [ "$#" -eq 0 ]; then
    echo "Error: No arguments provided. You must specify a single docker service for concept replacement."
    exit 1
fi

# Change to the desired directory
cd /srv/www/leaf/leaf-environments/dev || exit

# Run the command and assign the output to a variable
container_name=$(docker inspect --format '{{.Name}}' $(docker compose ps -q $1) | sed 's|^/||')

echo "Copying SQL inserts to $container_name ..."
echo " "

# Copy the insert statements into the Docker container

docker cp appConcept.sql "$container_name:/tmp/appConcept.sql"
docker cp appConceptSqlSet.sql "$container_name:/tmp/appConceptSqlSet.sql"
docker cp appSpecialization.sql "$container_name:/tmp/appSpecialization.sql"
docker cp appSpecializationGroup.sql "$container_name:/tmp/appSpecializationGroup.sql"

echo "Copying completed."
echo " "

echo "Deleting old concepts and inserting new ones ..."

# Insert the new concepts and specializations

cat insert_concepts.sh | docker exec -i "$container_name" bash
