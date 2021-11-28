@set RUNNER_ibconnection="/FD:/Базы данных/АПК"
@set RUNNER_dbuser="Автор"

@call runner run --command "acc.propertiesPaths=D:\repo\kurs_devops_1\tools\acc-export\acc.properties;" --execute "D:\repo\kurs_devops_1\tools\acc-export\acc-export.epf" --ordinaryapp 1
