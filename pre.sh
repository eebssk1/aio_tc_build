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
apt-get install -y zlib1g-dev libzstd-dev libgmp-dev libmpc-dev pkg-config libisl-dev libc6-dev-i386
fi

git config --system --add safe.directory '*'

if [ ! -e m_binutils ]; then
git clone --single-branch --depth=1 https://github.com/eebssk1/m_binutils || exit 255
fi
if [ ! -e m_gcc ]; then
git clone --single-branch --depth=1 https://github.com/eebssk1/m_gcc || exit 255
fi

if [ ! -e m_gcc ] && [ ! -e m_binutils ]; then
echo Unkown Error !; exit 255
fi

echo "This: $(git log --no-decorate -1 --oneline)" >> notes.txt
echo "GCC: $(cd m_gcc; git log --no-decorate -1 --oneline)" >> notes.txt
echo "BinUtils: $(cd m_binutils; git log --no-decorate -1 --oneline)" >> notes.txt


if [ -e x86_64-linux-gnu ]; then
echo "Hmm? Huh!"
else
if [ x$NO_TC_DOWN = x ] && ( [ ! -e /opt/newcc ] || [ ! -e ~/x86_64-linux-gnu ] ); then
curl -L "https://github.com/eebssk1/aio_tc_build/releases/download/8c4d2a0f/x86_64-linux-gnu-native.tb2" | tar --bz -xf -
mv x86_64-linux-gnu /opt/newcc
fi
fi

rm -rf m_*/build
rm -rf out
rm -rf *.tgz *.tb2
rm -rf time-*
rm -rf tmp
rm -rf x86_64-* i686-* aarch-* arm*-*
