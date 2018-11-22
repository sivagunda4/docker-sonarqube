#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

port=9000

warn() {
    echo "[warn] $@" >&2
}

info() {
    echo "[info] $@"
}

wait_for_sonarqube() {
    local image=$1 i web_up=no sonarqube_up=no

    for ((i = 0; i < 10; i++)); do
        info "$image: waiting for web server to start ..."
        if curl -sI localhost:$port | grep '^HTTP/.* 200'; then
            web_up=yes
            break
        fi
        sleep 3
    done

    [ "$web_up" = yes ] || return 1

    for ((i = 0; i < 10; i++)); do
        info "$image: waiting for sonarqube to be ready ..."
        if curl -s localhost:$port/api/system/status | grep '"status":"UP"'; then
            sonarqube_up=yes
            break
        fi
        sleep 5
    done

    [ "$sonarqube_up" = yes ]
}

sanity_check_image() {
    local image=$1

    id=$(docker run -d -p $port:9000 "$image")
    info "$image: container started with id=$id"

    if wait_for_sonarqube "$image"; then
        info "$image: OK !"
    else
        warn "$image: could not confirm service started"
    fi

    docker container stop "$id"
}

for image in [67]*-community; do
    name=sqtest:$image
    docker build -t "$name" -f "$image/Dockerfile" "$PWD/$image"
    sanity_check_image "$name"
done
