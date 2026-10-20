#!/bin/sh -eux

mkdir -p "{{project_path 'node/log'}}"

exec supercronic {{project_path 'node/cron/crontab'}}
