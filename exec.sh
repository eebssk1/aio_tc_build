#!/bin/sh

if [ "$1" != "mingw64-msys2" ]; then
if [ x$IN0 = x ]; then
export IN0=1
exec stdbuf -oL $0 "$@"
fi

if [ x$IN1 = x ]; then
export IN1=1
exec script -q -e -c "$0 "$@"" ./out.log
fi
fi

ulimit -S -s 32768
ulimit -S -a
ulimit -H -a

if [ -e /etc/environment ]; then
. /etc/environment
fi

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

echo Running PRE script
$CUR/pre.sh || exit 255

chrt -b --pid 0 $$
renice 3 $$

echo Running Target script
case "$1" in
linux-native)
exec $CUR/native.sh
;;
linux-native-profile)
exec $CUR/native.sh profile
;;
mingw64-win)
exec $CUR/mingw64-n.sh
;;
mingw64-msys2)
exec $CUR/mingw64-ms2.sh
;;
mingw64-cross)
exec $CUR/mingw64.sh
;;
mingw64-legacy-cross)
exec $CUR/mingw64.sh legacy
;;
mingw64-legacy-super-cross)
exec $CUR/mingw64.sh legacy_super
;;
mingw32-cross)
echo this build is included in mingw64 as multilib/arch now !
exit 0
;;
arm64-cross)
exec $CUR/arm.sh 64
;;
arm32-cross)
exec $CUR/arm.sh 32
;;
musl-cross)
exec $CUR/musl.sh
;;
*)
echo "unknown target !"
exit 255
;;
esac
