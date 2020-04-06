#!/bin/bash

# Run these commands as the 'qt' user

git clone https://github.com/supercollider/supercollider.git
cd supercollider
git checkout Version-3.11.0

# Note: this is building supernova also, but Sonic Pi doesn't use it.

git submodule update --init --recursive
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DSC_QT=OFF -DNATIVE=ON -DSC_EL=OFF ..
make -j4
# sudo make install # Umm, there's no sudo...need to run these as root
# sudo ldconfig
