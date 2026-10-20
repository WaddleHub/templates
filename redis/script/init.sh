#!/bin/sh -eux

# Point Redis at the project-local data directory.
redis-cli config set dir "{{project_path 'redis/data'}}"

# Keep accepting writes even if a background snapshot (RDB save) fails. This service is used
# as an ephemeral cache, so a failed save must never block the application.
redis-cli config set stop-writes-on-bgsave-error no

# Free memory asynchronously so large evictions/expirations do not block the event loop.
{{#if (version_compare tags.redis.version.raw '>=' '4.0.0')}}
redis-cli config set lazyfree-lazy-eviction yes
redis-cli config set lazyfree-lazy-expire yes
redis-cli config set lazyfree-lazy-server-del yes
{{/if}}
{{#if (version_compare tags.redis.version.raw '>=' '5.0.0')}}
redis-cli config set replica-lazy-flush yes
{{/if}}
{{#if (version_compare tags.redis.version.raw '>=' '6.0.0')}}
redis-cli config set lazyfree-lazy-user-del yes
{{/if}}

# Allow connections from the other containers on the project network (paired with the explicit
# bind in run.sh).
{{#if (version_compare tags.redis.version.raw '>=' '3.2.0')}}
redis-cli config set protected-mode no
{{/if}}

# Persist the applied settings to the config file.
redis-cli config rewrite
