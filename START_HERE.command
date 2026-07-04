#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"
./doctor.sh
./build.sh --clean --run
printf '\nPress Return to close…'
read -r _
