#!/bin/bash

# Run these commands as the 'qt' user

git clone --recursive https://github.com/supercollider/sc3-plugins.git
cd sc3-plugins/
mkdir build
cd build
cmake -DSC_PATH=../../supercollider ..
cmake --build  . --config Release
# sudo cmake --build  . --config Release --target install
