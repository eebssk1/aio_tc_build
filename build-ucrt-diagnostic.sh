#!/bin/bash

command -v gcc || exit 255
gcc -dumpmachine || exit 255

set -o pipefail
set +e
./exec.sh mingw64-msys2 2>&1 | tee ucrt64-full-build.log
build_status=${PIPESTATUS[0]}
set -e

if [ "$build_status" != 0 ]; then
  if [ -d x86_64-w64-mingw32-msys2 ]; then
    tar -I 'bzip2 -1' -cf ucrt64-failed-toolchain.tb2 \
      x86_64-w64-mingw32-msys2 ucrt64-full-build.log
  elif [ -d out ]; then
    tar -I 'bzip2 -1' -cf ucrt64-failed-toolchain.tb2 \
      out ucrt64-full-build.log
  fi
fi

exit "$build_status"
