#!/usr/bin/env bash
set -euo pipefail

bundle exec rails server -b 0.0.0.0 -p "${PORT:-3000}"
