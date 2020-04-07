#!/bin/bash

# Run with:
# sudo docker run -u root -it -v $(pwd):/var/build darkmattercoder/qt-build:5.14.1 bash

cd /var/build

# Install dependencies of Sonic Pi and Supercollider
apt-get update
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


#################################################################################
# Build Supercollider

(
    git clone https://github.com/supercollider/supercollider.git
    cd supercollider
    git checkout Version-3.11.0
    git submodule update --init --recursive
    mkdir build
    cd build
    # Note: I want to disable the unnecessary supernova, but this failed: -DNOVA_SIMD=OFF 
    cmake -DCMAKE_BUILD_TYPE=Release -DSC_QT=OFF -DSUPERNOVA=off -DSC_EL=OFF ..
    make -j4
    make install
    ldconfig
)


#################################################################################
# Build Supercollider Plugins

(
    git clone --recursive https://github.com/supercollider/sc3-plugins.git
    # TODO: check out a specific version instead of taking whatever's on master
    cd sc3-plugins/
    mkdir build
    cd build
    cmake -DSC_PATH=../../supercollider ..
    cmake --build  . --config Release
    cmake --build  . --config Release --target install
)


#################################################################################
# Build Sonic Pi

# Set up a directory the ruby build needs
mkdir -p /home/root/.sonic-pi
chown qt /home/root/.sonic-pi

# TODO: decide where to put the sonic-pi source dir - do I really want it to be a subdir of this build project?
(
    cd sonic-pi/app/server/ruby/
    rake
)

# Sonic Pi expects a Ruby here, otherwise it falls back to the system one.
mkdir -p sonic-pi/app/server/native/ruby/bin
cp /usr/bin/ruby sonic-pi/app/server/native/ruby/bin

(
    cd sonic-pi/app/gui/qt
    ./unix-prebuild.sh
    ./unix-config.sh
    cd build
    make -j4
)


#################################################################################
# Packaging

# Remove broken symlinks in the ruby installation that trip up exodus.
find -L /usr/lib/ruby/ -type l -delete

# Install Exodus via PIP (Note, maybe can skip pip and install exodus directly instead)
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py
pip install exodus-bundler

# Run exodus
find sonic-pi/app/server/ruby/ -type f | \
    grep -v '/test/' | grep -v '/tests/' | \
    grep -v '\.o$' | grep -v '\.c$' | grep -v '\.h$' |
exodus -t \
    -a /usr/local/plugins/platforms/libqxcb.so \
    -a /usr/local/plugins/xcbglintegrations/libqxcb-glx-integration.so \
    -a /usr/lib/ruby \
    -a /usr/lib/x86_64-linux-gnu/ruby \
    -a /usr/local/share/SuperCollider \
    -a sonic-pi/etc \
    -a sonic-pi/app/gui/qt/theme \
    /usr/local/bin/scsynth \
    sonic-pi/app/server/native/ruby/bin/ruby \
    sonic-pi/app/gui/qt/build/sonic-pi

# TODO: extract the tarball and patch things up

# Note: need to remove symlinks in the app/server/ruby directory for .rb files, otherwise
# the require_relative breaks.
# Here's maybe the easiest way to accomplish this task:
find exodus/bundles/*/usr/lib/ruby/ -name '*.rb' -exec sed -i '' '{}' \;
find exodus/bundles/*/var/build/sonic-pi/app/server/ruby -name '*.rb' -exec sed -i '' '{}' \;


# To Run:
# PATH=/home/spencer/code/sonic-pi-appimage/exodus/bin:$PATH RUBYLIB=/home/spencer/code/sonic-pi-appimage/exodus/bundles/ef76c6496cb321d03e6596af8119f4e0af37cb7acb8c5fc711cb51e05312fdac/usr/lib/ruby/2.5.0/ ./sonic-pi


# Note that it might be easier to just do a custom Ruby installation, although then again I'd
# still need exodus to resolve all the linker stuff so whatever.


