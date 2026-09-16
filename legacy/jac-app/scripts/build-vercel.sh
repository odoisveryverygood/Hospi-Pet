#!/usr/bin/env bash
set -euo pipefail

curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh \
  | bash -s -- --version 0.34.7
export PATH="$HOME/.local/bin:$PATH"

jac install
jac build --client static main.jac
cp public/favicon.ico .jac/client/dist/favicon.ico
