#!/bin/bash

if [ "$#" -eq 0 ]; then
    echo "Error: No arguments provided. You must specify a single docker service for concept export."
    exit 1
fi

cat generate_inserts.sh | docker exec -i $1 bash
docker cp $1:/tmp/appConcept.sql . 
docker cp $1:/tmp/appConceptSqlSet.sql . 
docker cp $1:/tmp/appSpecialization.sql . 
docker cp $1:/tmp/appSpecializationGroup.sql . 
