#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/cassava"
fpc -Mdelphi cassava.pas
