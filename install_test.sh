#!/bin/sh

set -e

# Lint.
# shellcheck -s sh ./*.sh

# Test that we can install the latest version at the default location.
rm -f ~/.wasmer/bin/wasmer
unset WASMER_DIR
sh ./install.sh
~/.wasmer/bin/wasmer --version

# Test that we can install a specific version at a custom location.
rm -rf ~/wasmer-0.17.0
export WASMER_DIR="$HOME/wasmer-0.17.0"
./install.sh 0.17.0
~/wasmer-0.17.0/bin/wasmer --version | grep 0.17.0
