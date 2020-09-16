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

# Test that upgrading versions work.
rm -f ~/.wasmer/bin/wasmer
unset WASMER_DIR
./install.sh 0.17.0
~/.wasmer/bin/wasmer --version | grep 0.17.0

unset WASMER_DIR
./install.sh 0.16.0
~/.wasmer/bin/wasmer --version | grep 0.17.0

unset WASMER_DIR
./install.sh 0.17.1
~/.wasmer/bin/wasmer --version | grep 0.17.1

unset WASMER_DIR
./install.sh 1.0.0-alpha3
~/.wasmer/bin/wasmer --version | grep 1.0.0-alpha3

unset WASMER_DIR
./install.sh 0.17.0
~/.wasmer/bin/wasmer --version | grep 1.0.0-alpha3
