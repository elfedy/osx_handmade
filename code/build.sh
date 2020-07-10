#/bin/bash

OSX_LD_FLAGS="-framework AppKit -framework IOKit -framework AudioToolbox"

mkdir ../../build
pushd ../../build
rm -rf handmade.app
mkdir -p handmade.app/Contents/Resources
clang -g $OSX_LD_FLAGS -o handmade.app/handmade ../handmade/code/osx_main.mm
cp "../handmade/resources/Info.plist" handmade.app/Info.plist
popd
