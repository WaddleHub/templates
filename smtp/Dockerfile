# -------------------------------------------------
# Runtime environment.
# -------------------------------------------------
#
# The SMTP relay is MailCatcher's remote counterpart. It accepts unauthenticated mail on the
# internal project network (via msmtpd) and forwards it to the configured external SMTP provider.
FROM {{public.smtp.docker.from}}

# Update repository and install the msmtp client, the msmtpd SMTP listener and CA certificates
# (needed to verify the external server's TLS certificate).
RUN set -eux; \
    {{get_additional_repos public.smtp.docker}}{{update_repo public.smtp.docker}}; \
    {{install public.smtp.docker packages.smtp.runtime}}; \
    msmtp --version; \
    command -v msmtpd
