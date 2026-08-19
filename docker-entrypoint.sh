#!/usr/bin/env bash
set -euo pipefail

bundle exec rake db:migrate

exec "$@"
