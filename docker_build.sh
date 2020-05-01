#!/bin/bash

# Install dependencies of Sonic Pi and Supercollider
apt-get update
apt-get install -y --no-install-recommends \
    musl-tools \
    \
    libaubio5 \
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
    libsctp1 \
    \
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

mkdir -p /var/src


# Install recent binary release of cmake - packaged version is a bit too old
(
    cd /var/src
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
    cd /var/src
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
    cd /var/src
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

export AUBIO_LIB=/usr/lib/x86_64-linux-gnu/libaubio.so.5
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

gcc /var/build/launcher.c -o /usr/bin/AppRun


#################################################################################
# Packaging

# Install Exodus via PIP (Note, maybe can skip pip and install exodus directly instead)
(
    cd /var/src
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py
    pip3 install exodus-bundler
)

libraries=$(cat \
    <(echo /usr/local/plugins/platforms/libqxcb.so) \
    <(echo /usr/local/plugins/xcbglintegrations/libqxcb-glx-integration.so) \
    <(echo /usr/lib/x86_64-linux-gnu/libaubio.so.5) \
    <(echo /usr/lib/x86_64-linux-gnu/libsctp.so.1) \
    <(find /opt/sonic-pi/app/server/ruby -name '*.so') \
    <(find /opt/ruby -name '*.so') \
    <(find /opt/supercollider -name '*.so')
)

# Run exodus
echo "Running Exodus..."
mkdir -p /var/staging
echo "$libraries" |
exodus -t \
    /opt/supercollider/bin/scsynth \
    /opt/ruby/bin/ruby \
    /usr/lib/erlang/erts-9.2/bin/erlexec \
    /usr/lib/erlang/erts-9.2/bin/beam.smp \
    /usr/lib/erlang/erts-9.2/bin/erl_child_setup \
    /usr/lib/erlang/bin/start.boot \
    /opt/sonic-pi/app/gui/qt/build/sonic-pi \
    /opt/sonic-pi/app/server/native/osmid/m2o \
    /opt/sonic-pi/app/server/native/osmid/o2m \
    /usr/bin/AppRun \
    -o /var/staging/exodus-sonic-pi.tgz


# Other binaries used:
# /bin/grep, /bin/ps, /bin/sed, jack_connect

# TODO: still need to add Erlang

mkdir -p /var/staging/AppImage/bundles/bundle
(
    cd /var/staging/AppImage/bundles/bundle

    mkdir -p opt/
    cp -r /opt/ruby/ opt/

    mkdir -p usr/lib/
    cp -r /usr/lib/erlang usr/lib

    mkdir -p opt/supercollider/share
    cp -r /opt/supercollider/share opt/supercollider

    mkdir -p opt/sonic-pi
    cp -r /opt/sonic-pi/etc opt/sonic-pi

    mkdir -p opt/sonic-pi/app/gui/qt
    cp -r /opt/sonic-pi/app/gui/qt/theme opt/sonic-pi/app/gui/qt

    mkdir -p opt/sonic-pi/app/server
    cp -r /opt/sonic-pi/app/server/ruby opt/sonic-pi/app/server
    patch -p1 < /var/build/scsynth_launch.diff

    cp -r /opt/sonic-pi/app/server/erlang opt/sonic-pi/app/server

    cd ../..
    tar -zxf ../exodus-sonic-pi.tgz 
    mv exodus/data .
    cp -r exodus/bundles/*/* bundles/bundle

    ln -s bundles/bundle/usr/bin/AppRun .

    # Symlinks to executables for convenience
    mkdir -p usr/bin
    cd usr/bin
    ln -s ../../bundles/bundle/opt/ruby/bin/ruby .
    ln -s ../../bundles/bundle/usr/lib/erlang/bin/erl .
    ln -s ../../bundles/bundle/opt/supercollider/bin/scsynth .
    ln -s ../../bundles/bundle/opt/sonic-pi/app/gui/qt/build/sonic-pi .
    ln -s ../../bundles/bundle//opt/sonic-pi/app/server/native/osmid/m2o .
    ln -s ../../bundles/bundle//opt/sonic-pi/app/server/native/osmid/o2m .

    # Prepare erlang scripts for relocation
    cd ../../bundles/bundle
    sed -ie 's,/usr/lib/erlang,\$ERLANG_ROOTDIR,' usr/lib/erlang/bin/erl
    sed -ie 's,/usr/lib/erlang,\$ERLANG_ROOTDIR,' usr/lib/erlang/bin/start
    sed -ie 's,/usr/lib/erlang,\$ERLANG_ROOTDIR,' usr/lib/erlang/erts-9.2/bin/erl
    sed -ie 's,/usr/lib/erlang,\$ERLANG_ROOTDIR,' usr/lib/erlang/erts-9.2/bin/start
    sed -ie 's,/usr/lib/erlang,\$ERLANG_ROOTDIR,' usr/lib/erlang/releases/RELEASES
)


# And finally, to create the AppImage:
curl -L https://github.com/AppImage/AppImageKit/releases/download/12/appimagetool-x86_64.AppImage --output /var/staging/appimagetool-x86_64.AppImage
chmod a+x /var/staging/appimagetool-x86_64.AppImage
cp /var/build/sonic-pi.desktop /var/staging/AppImage
cp /opt/sonic-pi/app/gui/qt/images/icon.png /var/staging/AppImage/sonic-pi.png
ARCH=x86_64 /var/staging/appimagetool-x86_64.AppImage --appimage-extract-and-run /var/staging/AppImage /var/build/sonic-pi.AppImage

chown 1000 /var/build/sonic-pi.AppImage
