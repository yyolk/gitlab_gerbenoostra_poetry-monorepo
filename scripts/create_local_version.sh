#!/bin/sh
set -x
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"/..
VERSION=$(dunamai from any)
echo $VERSION > VERSION
if [ "$(uname)" == "Darwin" ]; then export SEP=" "; else SEP=""; fi
sed -i$SEP'' "s/^version = .*/version = \"$VERSION\"/" package-a/pyproject.toml
sed -i$SEP'' "s/^version = .*/version = \"$VERSION\"/" package-b/pyproject.toml
sed -i$SEP'' "s/^__version__.*/__version__ = \"$(dunamai from any)\"/" package-a/package_a/__init__.py
sed -i$SEP'' "s/^__version__.*/__version__ = \"$(dunamai from any)\"/" package-b/package_b/__init__.py
