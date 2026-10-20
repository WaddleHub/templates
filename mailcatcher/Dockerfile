# -------------------------------------------------
# Compiletime routine.
# -------------------------------------------------
FROM {{public.mailcatcher.docker.from}} AS builder

# Install the MailCatcher gem and its native extensions into a self-contained prefix so the whole
# tree can be copied into a clean runtime stage without dragging the build toolchain along.
ENV GEM_HOME=/usr/local/mailcatcher
ENV GEM_PATH=/usr/local/mailcatcher

# Update repository, install packages required for the compilation routine and the MailCatcher gem.
RUN set -eux; \
    {{get_additional_repos public.mailcatcher.docker}}{{update_repo public.mailcatcher.docker}}; \
    {{install public.mailcatcher.docker packages.mailcatcher.compiletime}}; \
    gem install mailcatcher --no-document --bindir /usr/local/mailcatcher/bin; \
    /usr/local/mailcatcher/bin/mailcatcher --version

# -------------------------------------------------
# Runtime environment.
# -------------------------------------------------
FROM {{public.mailcatcher.docker.from}}

# Point Ruby at the copied gem prefix and expose its binstubs on the PATH.
ENV GEM_HOME=/usr/local/mailcatcher
ENV GEM_PATH=/usr/local/mailcatcher
ENV PATH="{{project_path 'bin'}}:/usr/local/mailcatcher/bin:$PATH"

# Copy the compiled MailCatcher gem tree from the builder stage.
COPY --from=builder /usr/local/mailcatcher /usr/local/mailcatcher

# Update repository, install runtime packages and confirm MailCatcher runs.
RUN set -eux; \
    {{get_additional_repos public.mailcatcher.docker}}{{update_repo public.mailcatcher.docker}}; \
    {{install public.mailcatcher.docker packages.mailcatcher.runtime}}; \
    mailcatcher --version
