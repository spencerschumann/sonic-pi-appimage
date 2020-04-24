#!/bin/bash

# Run with:
# docker run -u root -v $(pwd):/var/build darkmattercoder/qt-build:5.14.1 /var/build/build.sh

cd /var/build

# Install dependencies of Sonic Pi and Supercollider
apt-get update
apt-get install -y --no-install-recommends \
    musl-tools \
    \
    libaudio-dev \
    libjack-jackd2-dev \
    libsndfile1-dev \
    libasound2-dev \
    libavahi-client-dev \
    libreadline-dev \
    libfftw3-dev \
    libxt-dev \
    libudev-dev \
    libboost-dev \
    \
    erlang-base \
    file \
    \
    autoconf \
    bison \
    build-essential \
    libssl-dev \
    libyaml-dev \
    libreadline6-dev \
    zlib1g-dev \
    libncurses5-dev \
    libffi-dev \
    libgdbm-dev

#    libosmid-dev? But note that this is included in the Sonic Pi "external" directory.

mkdir -p /opt/src


# Install recent binary release of cmake - packaged version is a bit too old
(
    cd /opt
    curl -L https://github.com/Kitware/CMake/releases/download/v3.17.1/cmake-3.17.1-Linux-x86_64.tar.gz -o cmake.tgz
    tar --strip-components=1 -xf cmake.tgz -C /usr
)

export PATH=/opt/ruby/bin/:$PATH
(
    cd /var/src/
    git clone https://github.com/rbenv/ruby-build.git
    cd ruby-build/
    PREFIX=/opt/ruby ./install.sh
    ruby-build 2.7.1 /opt/ruby
    gem install ffi
)


#################################################################################
# Build Supercollider

(
    cd /opt/src
    git clone https://github.com/supercollider/supercollider.git
    cd supercollider
    git checkout Version-3.11.0
    git submodule update --init --recursive
    mkdir build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX=/opt/supercollider -DCMAKE_BUILD_TYPE=Release -DSC_QT=OFF -DSUPERNOVA=OFF -DSC_EL=OFF ..
    make -j4
    make install
    ldconfig
)


#################################################################################
# Build Supercollider Plugins

(
    cd /opt/src
    git clone --recursive https://github.com/supercollider/sc3-plugins.git
    git checkout Version-3.10.0
    cd sc3-plugins/
    mkdir build
    cd build
    cmake CMAKE_INSTALL_PREFIX=/opt/supercollider -DSUPERNOVA=OFF -DSC_PATH=../../supercollider ..
    cmake --build  . --config Release
    cmake --build  . --config Release --target install
)


#################################################################################
# Build Sonic Pi

(
    cd /opt
    git clone https://github.com/samaaron/sonic-pi.git
    cd sonic-pi
    git checkout v3.2.2
)

export AUBIO_LIB=/usr/lib/x86_64-linux-gnu/libaudio.so
(
    cd /opt/sonic-pi/app/server/ruby/
    rake
)

(
    cd /opt/sonic-pi/app/gui/qt
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

# Install Exodus via PIP (Note, maybe can skip pip and install exodus directly instead)
(
    cd /opt/src
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py
    pip3 install exodus-bundler
)

libraries=$(cat \
    <(echo /usr/local/plugins/platforms/libqxcb.so) \
    <(echo /usr/local/plugins/xcbglintegrations/libqxcb-glx-integration.so) \
    <(echo /usr/lib/x86_64-linux-gnu/libaudio.so) \
    <(find /opt/sonic-pi/app/server/ruby -name '*.so') \
    <(find /opt/ruby -name '*.so') \
    <(find /opt/supercollider -name '*.so')
)

# Run exodus
echo "Running Exodus..."
echo "$libraries" |
exodus -t \
    /opt/supercollider/bin/scsynth \
    /opt/ruby/bin/ruby \
    /opt/sonic-pi/app/gui/qt/build/sonic-pi \
    AppRun \
    -o exodus-sonic-pi.tgz

# Other binaries used:
# /bin/grep, /bin/ps, /bin/sed, jack_connect

# TODO: still need to add Erlang

mkdir -p AppImage/bundles/bundle
(
    cd AppImage/bundles/bundle

    mkdir -p opt/
    cp -r /opt/ruby/ opt/
    mkdir -p opt/supercollider/share
    cp -r /opt/supercollider/share opt/supercollider
    mkdir -p opt/sonic-pi
    cp -r /opt/sonic-pi/etc opt/sonic-pi
    mkdir -p opt/sonic-pi/app/gui/qt
    cp -r /opt/sonic-pi/app/gui/qt/theme opt/sonic-pi/app/gui/qt
    mkdir -p opt/sonic-pi/app/server
    cp -r /opt/sonic-pi/app/server/ruby opt/sonic-pi/app/server
    # TODO: need to patch scsynth_external.rb to allow the plugin path to be set via environment variable

    cd ../..
    tar -zxf ../exodus-sonic-pi.tgz 
    mv exodus/data .
    cp -r exodus/bundles/*/* bundles/bundle

    ln -s bundles/bundle/var/build/AppRun

    mkdir -p usr/bin
    cd usr/bin
    ln -s ../../bundles/bundle/opt/ruby/bin/ruby
    ln -s ../../bundles/bundle/opt/supercollider/bin/scsynth
    ln -s ../../bundles/bundle/opt/sonic-pi/app/gui/qt/build/sonic-pi
)

# And finally, to create the AppImage:
curl -L https://github.com/AppImage/AppImageKit/releases/download/12/appimagetool-x86_64.AppImage --output appimagetool-x86_64.AppImage
chmod a+x appimagetool-x86_64.AppImage
cp /var/build/sonic-pi.desktop AppImage
cp /opt/sonic-pi/app/gui/qt/images/icon.png AppImage/sonic-pi.png
ARCH=x86_64 ./appimagetool-x86_64.AppImage --appimage-extract-and-run AppImage sonic-pi.AppImage
