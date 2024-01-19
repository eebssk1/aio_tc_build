#!/bin/sh

ulimit -S -s 32768
ulimit -S -a
ulimit -H -a

. /etc/environment

CUR=$PWD

if [ "x$1" = "x" ]; then
echo "No target !"
exit 255
fi

echo Current path is $PWD
echo Target is $1

if [ -e /usr/lib/x86_64-linux-gnu/libjemalloc.so.2 ]; then
export LD_PRELOAD=libjemalloc.so.2
fi

if [ -e /usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4 ]; then
export LD_PRELOAD=libtcmalloc_minimal.so.4
fi

export GZIP_OPT=-7

echo Running PRE script
$CUR/pre.sh || exit 255

chrt -b --pid 0 $$
renice 3 $$

echo Running Target script
case "$1" in
linux-native)
$CUR/native.sh
;;
linux-native-profile)
$CUR/native.sh profile
;;
mingw64-cross)
$CUR/mingw64.sh
;;
mingw64-legacy-cross)
$CUR/mingw64.sh legacy
;;
mingw32-cross)
$CUR/mingw32.sh
;;
arm64-cross)
$CUR/arm.sh 64
;;
arm32-cross)
$CUR/arm.sh 32
;;
*)
echo "unknown target !"
exit 255
;;
esac
