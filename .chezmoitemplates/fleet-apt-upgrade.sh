#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
    echo "usage: fleet-apt-upgrade PACKAGE..." >&2
    exit 2
fi

for package in "$@"; do
    case "$package" in
        '' | -* | *[!abcdefghijklmnopqrstuvwxyz0123456789.+-]*)
            echo "fleet-apt-upgrade: refusing package name '$package'" >&2
            exit 2
            ;;
    esac
done

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
exec apt-get install -y --only-upgrade -o Dpkg::Options::=--force-confold "$@"
