#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

exec /opt/homebrew/bin/podman-compose \
	--podman-path /opt/homebrew/bin/podman \
	--podman-run-args=--memory-swap=2g \
	"$@" up -d --no-recreate
