#!/bin/sh

if [ "x$(which ccache)" != "x" ]; then
ccache -o compression_level=2
fi


apt-get install -y zlib1g-dev libzstd-dev libgmp-dev libmpc-dev pkg-config libisl-dev

if [ ! -e m_binutils ]; then
git clone --single-branch https://github.com/eebssk1/m_binutils
fi
if [ ! -e m_gcc ]; then
git clone --single-branch https://github.com/eebssk1/m_gcc
fi

curl -L "https://github.com/eebssk1/mingw-crt-build/releases/download/fe82ab31/mingw-crt.tgz" | tar -zxf -
