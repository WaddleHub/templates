#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download Kanboard source via git, from inside the php container rather than on the host: a
# host-side git clone leaves the tree owned by whatever account ran Waddle, and a rootless-Docker
# container's root can create new files alongside them but can never chown them afterward.
echo "[WADDLE] Downloading source."
docker compose exec -T php git clone --depth=1 --branch={{tags.website.version.full_raw}} \
    https://github.com/kanboard/kanboard.git "{{project_path 'website/src'}}"

# Drop the git metadata, so the project's repository tracks website/src as plain files.
echo "[WADDLE] Removing git metadata."
docker compose exec -T php find "{{project_path 'website/src'}}" -name .git -prune -exec rm -rf {} +

# Copy configuration file.
echo "[WADDLE] Applying configuration."
cp "./website/conf/kanboard/config.php" "./website/src/config.php"

# Run database migrations. On newer MariaDB, anonymous FK names differ from the
# legacy names Kanboard's older migrations expect (comments_ibfk_2,
# user_has_notifications_ibfk_1/2), causing DROP FOREIGN KEY to fail. If the first
# pass fails for this reason, a compatibility fix normalises all affected FK/index
# names before the second pass completes the remaining migrations.
#
# If the first pass succeeds (newer Kanboard has fixed its migrations, or the MariaDB
# version is compatible), the fix and second pass are skipped entirely.
echo "[WADDLE] Running database migrations."
set +e
docker compose exec -T php php "{{project_path 'website/src'}}/cli" db:migrate
MIGRATE_EXIT=$?
set -e

if [ "$MIGRATE_EXIT" -ne 0 ]; then

# Comprehensive MariaDB FK and index compatibility fix.
#
# Affected migrations:
#   version_75:  comments.comments_ibfk_2 (FK on task_id)
#   version_110: user_has_notifications FKs (ibfk_1 user_id, ibfk_2 project_id)
#                and independent index 'user_id' (DROP KEY `user_id`)
echo "[WADDLE] Applying MariaDB FK and index compatibility fix."
cat > "./website/src/.waddle_fk_fix.php" << 'PHP'
<?php
$dsn = 'mysql:host=db;port=3306;dbname={{public.website.db_name}};charset=utf8mb4';
$pdo = new PDO($dsn, getenv('WADDLE_DB_USER'), getenv('WADDLE_DB_PASSWORD'), [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

/**
 * Ensure a FK exists on $table.$column with exactly $expectedName.
 * Renames an existing FK for that column, or creates one if absent.
 */
function normalise_fk(PDO $pdo, string $table, string $column, string $expectedName,
                      string $refTable, string $refColumn, string $onDelete = ''): void
{
    $tableExists = (int) $pdo->query("
        SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{$table}'
    ")->fetchColumn();

    if (!$tableExists) {
        echo "[WADDLE] Table {$table} not found; skipping {$expectedName}.\n";
        return;
    }

    $alreadyCorrect = (int) $pdo->query("
        SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
        WHERE TABLE_SCHEMA    = DATABASE()
          AND TABLE_NAME      = '{$table}'
          AND CONSTRAINT_TYPE = 'FOREIGN KEY'
          AND CONSTRAINT_NAME = '{$expectedName}'
    ")->fetchColumn();

    if ($alreadyCorrect) {
        echo "[WADDLE] FK {$expectedName} already correct; skipping.\n";
        return;
    }

    $actualName = $pdo->query("
        SELECT kcu.CONSTRAINT_NAME
        FROM information_schema.KEY_COLUMN_USAGE kcu
        JOIN information_schema.TABLE_CONSTRAINTS tc
          ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
         AND kcu.TABLE_SCHEMA    = tc.TABLE_SCHEMA
         AND kcu.TABLE_NAME      = tc.TABLE_NAME
        WHERE kcu.TABLE_SCHEMA    = DATABASE()
          AND kcu.TABLE_NAME      = '{$table}'
          AND kcu.COLUMN_NAME     = '{$column}'
          AND tc.CONSTRAINT_TYPE  = 'FOREIGN KEY'
        LIMIT 1
    ")->fetchColumn();

    $onDeleteClause = $onDelete ? " ON DELETE {$onDelete}" : '';

    $pdo->exec('SET FOREIGN_KEY_CHECKS=0');

    if ($actualName) {
        echo "[WADDLE] Renaming FK {$actualName} -> {$expectedName} on {$table}.{$column}.\n";
        $pdo->exec("ALTER TABLE `{$table}` DROP FOREIGN KEY `{$actualName}`");
    } else {
        echo "[WADDLE] No FK for {$table}.{$column}; creating {$expectedName}.\n";
    }

    $pdo->exec(
        "ALTER TABLE `{$table}` ADD CONSTRAINT `{$expectedName}` " .
        "FOREIGN KEY (`{$column}`) REFERENCES `{$refTable}` (`{$refColumn}`){$onDeleteClause}"
    );

    $pdo->exec('SET FOREIGN_KEY_CHECKS=1');
    echo "[WADDLE] {$expectedName} normalised.\n";
}

/**
 * Ensure a non-unique single-column index on $table.$column is named $expectedName.
 * Drops any existing index for that column (excluding multi-column and UNIQUE ones)
 * and recreates it under the expected name.
 *
 * This is needed because when a FK is renamed, its auto-created backing index is
 * also renamed (or a new one is created under the FK name), but some migration
 * DROP KEY statements still expect the original column-named index.
 */
function normalise_index(PDO $pdo, string $table, string $column, string $expectedName): void
{
    $tableExists = (int) $pdo->query("
        SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{$table}'
    ")->fetchColumn();

    if (!$tableExists) {
        echo "[WADDLE] Table {$table} not found; skipping index {$expectedName}.\n";
        return;
    }

    // Check whether the index already has the correct name.
    $alreadyCorrect = (int) $pdo->query("
        SELECT COUNT(*) FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME   = '{$table}'
          AND INDEX_NAME   = '{$expectedName}'
          AND COLUMN_NAME  = '{$column}'
          AND SEQ_IN_INDEX = 1
          AND NON_UNIQUE   = 1
    ")->fetchColumn();

    if ($alreadyCorrect) {
        echo "[WADDLE] Index {$expectedName} already correct; skipping.\n";
        return;
    }

    // Find all non-unique, single-column indexes covering this column.
    $rows = $pdo->query("
        SELECT DISTINCT INDEX_NAME
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME   = '{$table}'
          AND COLUMN_NAME  = '{$column}'
          AND SEQ_IN_INDEX = 1
          AND NON_UNIQUE   = 1
          AND INDEX_NAME  != '{$expectedName}'
    ")->fetchAll(PDO::FETCH_COLUMN);

    $pdo->exec('SET FOREIGN_KEY_CHECKS=0');

    foreach ($rows as $idxName) {
        echo "[WADDLE] Dropping old index {$idxName} on {$table}.{$column}.\n";
        $pdo->exec("ALTER TABLE `{$table}` DROP INDEX `{$idxName}`");
    }

    // Recreate with the expected name.
    echo "[WADDLE] Creating index {$expectedName} on {$table}.{$column}.\n";
    $pdo->exec("CREATE INDEX `{$expectedName}` ON `{$table}` (`{$column}`)");

    $pdo->exec('SET FOREIGN_KEY_CHECKS=1');
    echo "[WADDLE] Index {$expectedName} normalised.\n";
}

// version_75: comments.task_id -> tasks.id
normalise_fk($pdo, 'comments', 'task_id', 'comments_ibfk_2', 'tasks', 'id');

// version_110: FK and index normalisation for user_has_notifications.
//
// normalise_fk renames the FK constraint but leaves the backing index under whatever
// name MariaDB assigned it (e.g. the old constraint name). normalise_index then
// ensures a standalone index named 'user_id' exists, which version_110's
// `ALTER TABLE user_has_notifications DROP KEY 'user_id'` requires.
normalise_fk($pdo, 'user_has_notifications', 'user_id',
             'user_has_notifications_ibfk_1', 'users', 'id', 'CASCADE');
normalise_fk($pdo, 'user_has_notifications', 'project_id',
             'user_has_notifications_ibfk_2', 'projects', 'id', 'CASCADE');
normalise_index($pdo, 'user_has_notifications', 'user_id', 'user_id');

echo "[WADDLE] FK and index compatibility fix complete.\n";
PHP
docker compose exec -T php php "{{project_path 'website/src'}}/.waddle_fk_fix.php"
rm -f "./website/src/.waddle_fk_fix.php"

echo "[WADDLE] Running database migrations (pass 2)."
docker compose exec -T php php "{{project_path 'website/src'}}/cli" db:migrate

fi

# Update the default admin account with the configured credentials.
echo "[WADDLE] Configuring admin account."
cat > "./website/src/.waddle_admin_setup.php" << 'PHP'
<?php
$dsn = 'mysql:host=db;port=3306;dbname={{public.website.db_name}};charset=utf8mb4';
$pdo = new PDO($dsn, getenv('WADDLE_DB_USER'), getenv('WADDLE_DB_PASSWORD'), [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

$username = '{{public.website.admin_username}}';
$email    = '{{public.website.admin_email}}';
$password = password_hash(getenv('WADDLE_ADMIN_PASSWORD'), PASSWORD_DEFAULT);
$name     = '{{public.website.title}}';

$pdo->prepare('UPDATE users SET username = ?, password = ?, email = ?, name = ? WHERE id = 1')
    ->execute([$username, $password, $email, $username]);

$pdo->prepare("UPDATE settings SET value = ? WHERE option = 'application_name'")
    ->execute([$name]);

// Insert application_name if it does not already exist.
$count = (int) $pdo->query("SELECT COUNT(*) FROM settings WHERE option = 'application_name'")->fetchColumn();

if ($count === 0) {
    $pdo->prepare("INSERT INTO settings (option, value) VALUES ('application_name', ?)")
        ->execute([$name]);
}

echo "[WADDLE] Admin account configured.\n";
PHP
docker compose exec -T -e WADDLE_ADMIN_PASSWORD="${WADDLE_ADMIN_PASSWORD}" php php "{{project_path 'website/src'}}/.waddle_admin_setup.php"
rm -f "./website/src/.waddle_admin_setup.php"
