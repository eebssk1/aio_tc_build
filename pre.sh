#!/bin/sh

if [ "x$(which ccache)" != "x" ]; then
ccache -o compression_level=2
fi


if [ "$(whoami)" != "root" ]; then
echo Not root, not install dep!
else
apt-get update -y
apt-get upgrade -y
apt-get install --reinstall -y build-essential libtcmalloc-minimal4 bsdextrautils bison flex
apt-get install --reinstall -y libc6-dev zlib1g-dev libzstd-dev libgmp-dev libmpc-dev pkg-config libisl-dev musl musl-dev time
apt-get install --reinstall -y libc6-dev-i386 || true
fi

git config --system --add safe.directory '*'

if [ ! -e m_binutils ]; then
git clone --single-branch --depth=5 https://github.com/eebssk1/m_binutils || exit 255
fi
if [ ! -e m_gcc ]; then
git clone --single-branch --depth=5 https://github.com/eebssk1/m_gcc || exit 255
fi

if [ ! -e m_gcc ] || [ ! -e m_binutils ]; then
echo Unkown Error !; exit 255
fi

check_commit() {
    CDIR=$(pwd)
    case "$1" in
        gcc)
        PRE="GCC:"
        DIR=m_gcc
        ;;
        binutils)
        PRE="BinUtils:"
        DIR=m_binutils
        ;;
        this)
        PRE="This:"
        DIR=.
        ;;
        *)
        exit 255
        ;;
    esac
    TXT=../notes.txt
    if [ "$DIR" = "." ]; then
        TXT=./notes.txt
    fi
    cd "$DIR"
    echo "$PRE $(git log --no-merges --no-decorate -1 --oneline)" >> "$TXT"
    cd "$CDIR"
}

check_commit this
check_commit gcc
check_commit binutils


if [ -e x86_64-linux-gnu ] || [ "$SYS_TC" = "true" ]; then
echo "Hmm? Huh!"
else
if [ x$NO_TC_DOWN = x ] && ( [ ! -e /opt/newcc ] || [ ! -e ~/x86_64-linux-gnu ] ); then
curl -L "https://github.com/eebssk1/aio_tc_build/releases/latest/download/x86_64-linux-gnu-native.tb2" | tar --bz -xf -
mv x86_64-linux-gnu /opt/newcc
fi
fi

git clone https://git.code.sf.net/p/mingw-w64/mingw-w64 -b master --depth=5 mingw-w64-mingw-w64 || exit 255
cd mingw-w64-mingw-w64
echo "MINGW: $(git log --no-merges --no-decorate -1 --oneline)" >> ../note.txt
cd ..

if [ "$MG" != "1" ]; then
rm -rf mingw-w64-mingw-w64
fi

rm -rf m_*/build
rm -rf out
rm -rf *cross*.tb2 *native*.tb2
rm -rf time-*
rm -rf tmp
rm -rf x86_64-* i686-* aarch*-* arm*-*
