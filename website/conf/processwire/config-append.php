// Appended to site/config.php by the installer.

// ==========================================
// Waddle-generated configuration
// ==========================================
$config->dbHost = 'db';
$config->dbName = '{{public.website.db_name}}';
$config->dbUser = '{{private.website_credentials.db_username}}';
$config->dbPass = '{{private.website_credentials.db_password}}';
$config->dbPort = '3306';
$config->dbCharset = 'utf8mb4';
$config->dbEngine = 'InnoDB';
$config->userAuthSalt = '{{private.secrets.pw_user_auth_salt}}';
$config->tableSalt = '{{private.secrets.pw_table_salt}}';
$config->chmodDir = '0755';
$config->chmodFile = '0644';
$config->timezone = '{{timezone}}';
$config->httpHosts = array('{{public.website.url}}');
$config->debug = false;
$config->sessionName = 'pw{{private.secrets.pw_session_name}}';
