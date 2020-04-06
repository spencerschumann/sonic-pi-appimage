#!/bin/bash

# Run these commands as the 'qt' user

cd sonic-pi/app/server/ruby/
rake


mkdir -p sonic-pi/app/server/native/ruby/bin     
cp /usr/bin/ruby sonic-pi/app/server/native/ruby/bin 

(
    cd sonic-pi/app/gui/qt
    ./unix-prebuild.sh 
    ./unix-config.sh 
)

(cd sonic-pi/app/gui/qt/build/ && make -j4) \

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
    /usr/local/bin/scsynth \
    sonic-pi/app/gui/qt/theme \
    sonic-pi/app/server/native/ruby/bin/ruby \
    sonic-pi/app/gui/qt/build/sonic-pi | tar -zx

# Note: need to remove symlinks in the app/server/ruby directory for .rb files, otherwise
# the require_relative breaks.
# Here's maybe the easiest way to accomplish this task:
# $ find ../exodus/bundles/x/usr/lib/ruby/ -name '*.rb' -exec sed -i '' '{}' \;

# Also make sure to pass RUBYLIB when running, example:
# $ RUBYLIB=/home/spencer/code/sonic-pi-appimage/exodus/bundles/x/usr/lib/ruby/2.5.0/ exodus/bundles/x/var/build/sonic-pi/app/gui/qt/build/sonic-pi

# Note that it might be easier to just do a custom Ruby installation, although then again I'd
# still need exodus to resolve all the linker stuff so whatever.
