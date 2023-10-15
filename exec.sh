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

apt-get update -y
apt-get upgrade -y

apt-get install -y libtcmalloc-minimal4 bsdextrautils

export LD_PRELOAD=libtcmalloc_minimal.so.4

export GZIP_OPT=-7

echo Running PRE script
$CUR/pre.sh

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
