<?php

use function Cake\Core\env;

/*
 * Local configuration overrides.
 */
return [
    'debug' => filter_var(env('DEBUG', true), FILTER_VALIDATE_BOOLEAN),

    'Security' => [
        'salt' => env('SECURITY_SALT', '{{private.secrets.cakephp_security_salt}}'),
    ],

{{#if public.mariadb.install}}
    'Datasources' => [
        'default' => [
            'host' => 'db',
            'username' => '{{private.website_credentials.db_username}}',
            'password' => '{{private.website_credentials.db_password}}',
            'database' => '{{public.website.db_name}}',
            'url' => env('DATABASE_URL', null),
        ],

        // The test connection is used during the test suite.
        'test' => [
            'url' => env('DATABASE_TEST_URL', 'sqlite://127.0.0.1/tmp/tests.sqlite'),
        ],
    ],

{{/if}}
    // Mail — delivered to the internal `mail` service (MailCatcher locally, SMTP relay on remotes).
    'EmailTransport' => [
        'default' => [
            'className' => \Cake\Mailer\Transport\SmtpTransport::class,
            'host' => 'mail',
            'port' => {{public.mail.smtp_port}},
            'username' => null,
            'password' => null,
            'client' => null,
            'url' => env('EMAIL_TRANSPORT_DEFAULT_URL', null),
        ],
    ],

    'Email' => [
        'default' => [
            'transport' => 'default',
            'from' => '{{coalesce public.mail.from_email public.website.admin_email}}',
        ],
    ],
];
