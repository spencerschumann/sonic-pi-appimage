#!/bin/bash

# Run with:
# docker run -u root -v $(pwd):/var/build darkmattercoder/qt-build:5.14.1 /var/build/build.sh

cd /var/build

# Install dependencies of Sonic Pi and Supercollider
apt-get update
apt-get install -y --no-install-recommends \
    musl-tools \
    ruby2.5-dev \
    ruby-ffi \
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
    erlang-base \
    file

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
    cmake -DCMAKE_BUILD_TYPE=Release -DSC_QT=OFF -DSUPERNOVA=OFF -DSC_EL=OFF ..
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
    cmake -DSUPERNOVA=OFF -DSC_PATH=../../supercollider ..
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
    git clone https://github.com/samaaron/sonic-pi.git
    cd sonic-pi
    git checkout v3.2.0
)

(
    cd sonic-pi/app/server/ruby/
    rake
)

(
    cd sonic-pi/app/gui/qt
    ./unix-prebuild.sh
    ./unix-config.sh
    cd build
    make -j4
)


#################################################################################
# Build the launcher

gcc launcher.c -o AppRun


#################################################################################
# Packaging

# Remove broken symlinks in the ruby installation that trip up exodus.
#find -L /usr/lib/ruby/ -type l -delete

# Install Exodus via PIP (Note, maybe can skip pip and install exodus directly instead)
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py
pip3 install exodus-bundler

libraries=$(cat \
    <(find sonic-pi/app/server/ruby) \
    <(echo /usr/local/plugins/platforms/libqxcb.so) \
    <(echo /usr/local/plugins/xcbglintegrations/libqxcb-glx-integration.so) \
    <(find /usr/lib/ruby) \
    <(find /usr/lib/x86_64-linux-gnu/ruby) \
    <(find /usr/local/share/SuperCollider) \
    <(find sonic-pi/etc) \
    <(find sonic-pi/app/gui/qt/theme) | \
    grep '\.so$' \
)

# Run exodus
echo "Running Exodus..."
echo "$libraries" |
exodus -t \
    /usr/local/bin/scsynth \
    /usr/bin/ruby \
    sonic-pi/app/gui/qt/build/sonic-pi \
    AppRun \
    -o exodus-sonic-pi.tgz

mkdir -p AppImage/bundles/bundle
(
    cd AppImage/bundles/bundle

    mkdir -p usr/lib
    cp -r /usr/lib/ruby/ usr/lib/
    mkdir -p usr/lib/x86_64-linux-gnu/ruby/
    cp -r /usr/lib/x86_64-linux-gnu/ruby usr/lib/x86_64-linux-gnu
    mkdir -p usr/local/share
    cp -r /usr/local/share/SuperCollider/ usr/local/share/
    mkdir -p var/build/sonic-pi
    cp -r /var/build/sonic-pi/etc var/build/sonic-pi
    mkdir -p var/build/sonic-pi/app/gui/qt
    cp -r /var/build/sonic-pi/app/gui/qt/theme var/build/sonic-pi/app/gui/qt
    mkdir -p var/build/sonic-pi/app/server
    cp -r /var/build/sonic-pi/app/server/ruby var/build/sonic-pi/app/server

    cd ../..
    tar -zxf ../exodus-sonic-pi.tgz 
    mv exodus/data .
    cp -r exodus/bundles/*/* bundles/bundle

    ln -s bundles/bundle/var/build/AppRun

    mkdir -p usr/bin
    cd usr/bin
    ln -s ../../bundles/bundle/usr/bin/ruby
    ln -s ../../bundles/bundle/usr/local/bin/scsynth
    ln -s ../../bundles/bundle/var/build/sonic-pi/app/gui/qt/build/sonic-pi
)

# Note that it might be easier to just do a custom Ruby installation, although then again I'd
# still need exodus to resolve all the linker stuff so whatever.

# And finally, to create the AppImage:
curl -L https://github.com/AppImage/AppImageKit/releases/download/12/appimagetool-x86_64.AppImage --output appimagetool-x86_64.AppImage
chmod a+x appimagetool-x86_64.AppImage 
cp sonic-pi.desktop AppImage
cp sonic-pi/app/gui/qt/images/icon.png AppImage/sonic-pi.png
ARCH=x86_64 ./appimagetool-x86_64.AppImage --appimage-extract-and-run AppImage sonic-pi.AppImage
