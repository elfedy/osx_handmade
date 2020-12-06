#/bin/bash

OSX_LD_FLAGS="-framework AppKit -framework IOKit -framework AudioToolbox"
DISABLED_WARNINGS="-Wno-old-style-cast
                  -Wno-cast-qual
                  -Wno-gnu-anonymous-struct
                  -Wno-nested-anon-types
                  -Wno-padded
                  -Wno-pedantic
                  -Wno-unused-variable
                  -Wno-unused-parameter
                  -Wno-missing-prototypes
                  -Wno-nullable-to-nonnull-conversion
                  -Wno-c++11-long-long"

COMMON_COMPILER_FLAGS="-Werror -Weverything
                      $DISABLED_WARNINGS
                      -DHANDMADE_INTERNAL=1"

mkdir ../../build
pushd ../../build
rm -rf handmade.app
mkdir -p handmade.app/Contents/Resources
clang -g -o GameCode.dylib $COMMON_COMPILER_FLAGS -dynamiclib ../handmade/code/handmade.cpp
clang -g $COMMON_COMPILER_FLAGS $OSX_LD_FLAGS -o handmade.app/handmade ../handmade/code/osx_main.mm
cp ../handmade/resources/Info.plist handmade.app/
cp ../handmade/resources/test_background.bmp handmade.app/Contents/Resources/
cp GameCode.dylib handmade.app/Contents/Resources/GameCode.dylib
cp -r GameCode.dylib.dSYM handmade.app/Contents/Resources/GameCode.dylib.dSYM
popd
