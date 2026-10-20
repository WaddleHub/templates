#!/bin/sh -eux

mkdir -p "{{project_path 'php/log'}}"

exec supercronic {{project_path 'php/cron/crontab'}}
