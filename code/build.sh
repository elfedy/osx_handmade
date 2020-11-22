#/bin/bash

OSX_LD_FLAGS="-framework AppKit -framework IOKit -framework AudioToolbox"

mkdir ../../build
pushd ../../build
rm -rf handmade.app
mkdir -p handmade.app/Contents/Resources
clang -g "-DHANDMADE_INTERNAL=1" $OSX_LD_FLAGS -o handmade.app/handmade ../handmade/code/osx_main.mm
cp "../handmade/resources/Info.plist" handmade.app/
cp "../handmade/resources/test_background.bmp" handmade.app/Contents/Resources/
popd
