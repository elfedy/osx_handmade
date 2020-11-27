#/bin/bash

OSX_LD_FLAGS="-framework AppKit -framework IOKit -framework AudioToolbox"
DISABLED_WARNINGS="-Wno-old-style-cast
                  -Wno-cast-qual
                  -Wno-gnu-anonymous-struct
                  -Wno-nested-anon-types
                  -Wno-padded
                  -Wno-unused-variable
                  -Wno-unused-parameter
                  -Wno-missing-prototypes
                  -Wno-nullable-to-nonnull-conversion
                  -Wno-c++11-long-long"


mkdir ../../build
pushd ../../build
rm -rf handmade.app
mkdir -p handmade.app/Contents/Resources
clang -g -Werror -Weverything $DISABLED_WARNINGS "-DHANDMADE_INTERNAL=1" $OSX_LD_FLAGS -o handmade.app/handmade ../handmade/code/osx_main.mm
cp "../handmade/resources/Info.plist" handmade.app/
cp "../handmade/resources/test_background.bmp" handmade.app/Contents/Resources/
popd
