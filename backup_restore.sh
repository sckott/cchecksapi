# Backup
docker exec cchecksapi_mariadb_1 /usr/bin/mysqldump -u root --password=root cchecks > cchecks_backup.sql

# Restore
cat cchecks_backup.sql | docker exec -i cchecksapi_mariadb_1 /usr/bin/mysql -u root --password=root cchecks
