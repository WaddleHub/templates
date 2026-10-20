<?php

// Database
define('DB_DRIVER', 'mysql');
define('DB_HOSTNAME', 'db');
define('DB_PORT', 3306);
define('DB_NAME', '{{public.website.db_name}}');
// Credentials are lieterally rendered in this file because PHP FPM has no access to env vars.
define('DB_USERNAME', '{{private.website_credentials.db_username}}');
define('DB_PASSWORD', '{{private.website_credentials.db_password}}');

// Enable URL rewriting (requires the nginx try_files directive).
define('ENABLE_URL_REWRITE', true);

// Mail — delivered to the internal `mail` service (MailCatcher locally, SMTP relay on remotes).
define('MAIL_TRANSPORT', 'smtp');
define('MAIL_SMTP_HOSTNAME', 'mail');
define('MAIL_SMTP_PORT', {{public.mail.smtp_port}});
define('MAIL_FROM', '{{coalesce public.mail.from_email public.website.admin_email}}');
