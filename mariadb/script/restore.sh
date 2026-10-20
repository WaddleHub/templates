#!/bin/sh -eu

# Restore a dump made by backup.sh, replacing the current databases.
#
# Every non-system database is dropped first, so databases and tables created since the dump
# don't survive the restore. The dump recreates each database it holds. The `mysql` system
# schema isn't dropped, the dump replaces its tables though.
#
# Usage: sh restore.sh <file>
#   <file>  Path inside the container to a dump made by backup.sh.

FILE="${1}"

for db in $(mariadb -N -e "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')"); do
    mariadb -e "DROP DATABASE \`${db}\`"
done

mariadb < "${FILE}"
mariadb -e "FLUSH PRIVILEGES"
