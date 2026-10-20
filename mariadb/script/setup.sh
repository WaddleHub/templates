#!/bin/sh -eux

# Credentials are provided to the db container as environment variables (see docker-compose.yml),
# sourced from the gitignored .env — never rendered as literals into this committed script.
DB_USERNAME="${WADDLE_DB_USER}"
DB_PASSWORD="${WADDLE_DB_PASSWORD}"

# Deleting unsafe users (nameless / remote user).
echo "[Database] Deleting unsafe users."
mariadb -e "DELETE FROM mysql.user WHERE User = ''"
mariadb -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1', '0.0.0.0')"

# Deleting test database.
echo "[Database] Deleting test database."
mariadb -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"

# Flush user privileges.
echo "[Database] Flushing privileges."
mariadb -e "FLUSH PRIVILEGES"

{{#if (not_empty public.website.db_name)}}
    echo "[Database] Setting up new databases and users."

    # Create databases and users.
    mariadb -e "CREATE DATABASE IF NOT EXISTS {{public.website.db_name}} CHARACTER SET {{public.website.db_charset}} COLLATE {{public.website.db_collation}}"
    mariadb -e "CREATE USER IF NOT EXISTS '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD'"
    mariadb -e "GRANT ALL PRIVILEGES ON *.* TO '$DB_USERNAME'@'localhost'"
    mariadb -e "CREATE USER IF NOT EXISTS '$DB_USERNAME'@'%' IDENTIFIED BY '$DB_PASSWORD'"
    mariadb -e "GRANT ALL PRIVILEGES ON *.* TO '$DB_USERNAME'@'%'"

    # Flush privileges.
    echo "[Database] Flushing privileges."
    mariadb -e "FLUSH PRIVILEGES"
{{/if}}

# Run database upgrade procedure (updates system tables after a version change).
echo "[Database] Running upgrade procedure."
mariadb-upgrade
