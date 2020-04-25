#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

docker run -u root -v "$SCRIPT_DIR:/var/build" darkmattercoder/qt-build:5.14.1 /var/build/docker_build.sh
