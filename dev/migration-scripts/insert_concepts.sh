#!/bin/bash

# delete relationship entries to avoid foreign key errors which would otherwise occur on insert
/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [rela].[QueryConceptDependency]" && echo "- rela.QueryConceptDependency rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [rela].[ConceptSpecializationGroup]" && echo "- rela.ConceptSpecializationGroup rows deleted."

# delete concept and specialization entries from relevant tables before refreshing via insert
/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [app].[Specialization]" && echo "- app.Specialization rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [app].[Concept]" && echo "- app.Concept rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [app].[SpecializationGroup]" && echo "- app.SpecializationGroup rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [app].[ConceptSqlSet]" && echo "- app.ConceptSqlSet rows deleted."

# insert the new concept and specialization data into the tables on the receiving instance
/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -i /tmp/appConceptSqlSet.sql

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -i /tmp/appSpecializationGroup.sql

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -i /tmp/appSpecialization.sql

# here the -I switch is used to avoid errors regarding quoted identifiers
/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -I -i /tmp/appConcept.sql
