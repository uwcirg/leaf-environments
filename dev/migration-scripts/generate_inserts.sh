#!/bin/bash

# output insert statements for required concept-related tables
/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "EXEC sp_generate_inserts 'Specialization', @owner = 'app'" -o /tmp/appSpecialization.sql -y 0
/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "EXEC sp_generate_inserts 'Concept', @owner = 'app'" -o /tmp/appConcept.sql -y 0
/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "EXEC sp_generate_inserts 'ConceptSqlSet', @owner = 'app'" -o /tmp/appConceptSqlSet.sql -y 0
/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "EXEC sp_generate_inserts 'SpecializationGroup', @owner = 'app'" -o /tmp/appSpecializationGroup.sql -y 0

# remove trailing spaces within quoted strings, as these were not present in the original table
sed -Ei "s/('[^']*[^[:space:]])[[:space:]]*'/\1'/g" /tmp/appConcept.sql
sed -Ei "s/('[^']*[^[:space:]])[[:space:]]*'/\1'/g" /tmp/appSpecialization.sql
