#!/bin/sh -eux

# Ensure the log directory exists.
mkdir -p "{{project_path 'smtp/log'}}"

# Run the minimal SMTP listener. msmtpd accepts mail on the internal project network and pipes each
# received message to msmtp, which relays it to the configured external SMTP server.
exec msmtpd \
    --interface=0.0.0.0 \
    --port={{public.mail.smtp_port}} \
    --log={{project_path 'smtp/log/msmtpd.log'}} \
    --command="msmtp -C {{project_path 'smtp/conf/msmtprc'}} --"
