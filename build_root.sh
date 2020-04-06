#!/bin/bash

# Run these commands as the root user

# Install dependencies of Sonic Pi and 
# apt-get update
apt-get install -y --no-install-recommends \
    musl-tools \
    ruby2.5-dev \
    libaudio-dev \
    libjack-jackd2-dev \
    libsndfile1-dev \
    libasound2-dev \
    libavahi-client-dev \
    libreadline-dev \
    libfftw3-dev \
    libxt-dev \
    libudev-dev \
    cmake \
    libboost-dev \
    libffi-dev \
    libaubio-dev \
    erlang-base

#    libosmid-dev? But note that this is included in the Sonic Pi "external" directory.

#ruby-ffi?

# Remove broken symlinks in the ruby installation that trip up exodus.
find -L /usr/lib/ruby/ -type l -delete


# Install Exodus via PIP (Note, maybe can skip pip and install exodus directly instead)
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py
pip install exodus-bundler

# Set up a directory the ruby build needs
mkdir -p /home/qt/.sonic-pi
chown qt /home/qt/.sonic-pi
