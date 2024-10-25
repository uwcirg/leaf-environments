#!/bin/bash
/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [rela].[QueryConceptDependency]" && echo "- rela.QueryConceptDependency rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [rela].[ConceptSpecializationGroup]" && echo "- rela.ConceptSpecializationGroup rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [app].[Specialization]" && echo "- app.Specialization rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [app].[Concept]" && echo "- app.Concept rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [app].[SpecializationGroup]" && echo "- app.SpecializationGroup rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -Q "SET QUOTED_IDENTIFIER ON; DELETE FROM [app].[ConceptSqlSet]" && echo "- app.ConceptSqlSet rows deleted."

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -i /tmp/appConceptSqlSet.sql

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -i /tmp/appSpecializationGroup.sql

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -i /tmp/appSpecialization.sql

/opt/mssql-tools/bin/sqlcmd -d LeafDB -U sa -P ${SA_PASSWORD} -I -i /tmp/appConcept.sql
