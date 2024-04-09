#!/bin/sh

if [ "x$(which ccache)" != "x" ]; then
ccache -o compression_level=2
fi


if [ "$(whoami)" != "root" ]; then
echo Not root, not install dep!
else
apt-get update -y
apt-get upgrade -y
apt-get install -y libtcmalloc-minimal4 bsdextrautils
apt-get install -y zlib1g-dev libzstd-dev libgmp-dev libmpc-dev pkg-config libisl-dev
fi

if [ ! -e m_binutils ]; then
git clone --single-branch --depth=1 https://github.com/eebssk1/m_binutils || exit 255
fi
if [ ! -e m_gcc ]; then
git clone --single-branch --depth=1 https://github.com/eebssk1/m_gcc || exit 255
fi

if [ ! -e m_gcc ] && [ ! -e m_binutils ]; then
echo Unkown Error !; exit 255
fi

curl -L "https://github.com/eebssk1/aio_tc_build/releases/download/NG-01/x86_64-linux-gnu-native.tgz" | tar -zxf -
mv x86_64-linux-gnu /opt/newcc

rm -rf m_*/build
rm -rf out
rm -rf *.tgz
rm -rf time-*
