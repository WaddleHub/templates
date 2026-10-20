<?php

/*
 * Mail configuration.
 */
require '{{project_path 'website/src'}}/config/config.inc.php';

{{#if public.mail.enabled}}
// PrestaShop's default method builds Symfony Mailer's SendmailTransport without a command, which
// runs /usr/sbin/sendmail -bs and ignores PHP's sendmail_path (msmtp). That binary may or may not
// exist in the PHP image. Send over SMTP to the internal `mail` service instead (MailCatcher
// locally, SMTP relay on remotes).
Configuration::updateValue('PS_MAIL_METHOD', 2);
Configuration::updateValue('PS_MAIL_SERVER', 'mail');
Configuration::updateValue('PS_MAIL_SMTP_PORT', {{public.mail.smtp_port}});
Configuration::updateValue('PS_MAIL_SMTP_ENCRYPTION', 'off');
Configuration::updateValue('PS_MAIL_USER', '');
Configuration::updateValue('PS_MAIL_PASSWD', '');
{{else}}
// No mail service in this project, never send, rather than fail on every attempt.
Configuration::updateValue('PS_MAIL_METHOD', 3);
{{/if}}

// The contact form module sends nothing until these are switched on.
Configuration::updateValue('CONTACTFORM_SEND_NOTIFICATION_EMAIL', 1);
Configuration::updateValue('CONTACTFORM_SEND_CONFIRMATION_EMAIL', 1);

echo "[WADDLE] Mail configuration applied.\n";
