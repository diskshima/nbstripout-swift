#! /bin/bash

script_dir=$(cd $(dirname $0) && pwd)
root_dir=$(git rev-parse --show-toplevel)
checkout_dir=${root_dir}/.build/checkouts

echo "Patching files for Linux build."

patch -N ${checkout_dir}/ArgumentParserKit/ArgumentParserKit/Classes/OutputByteStream.swift ${script_dir}/ArgumentParserKit.patch
patch -N ${checkout_dir}/SwiftyJSON/Source/SwiftyJSON/SwiftyJSON.swift ${script_dir}/SwiftyJSON.patch
