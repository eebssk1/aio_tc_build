#!/bin/sh

CUR=$PWD

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
export LD_LIBRARY_PATH=/opt/newcc/lib
fi

case "$1" in
32)
BIT=32
TARGET=arm-linux-musleabihf
ADDI="--with-arch=armv7-a --with-fpu=neon --with-float=hard"
;;
64)
BIT=64
TARGET=aarch64-linux-musl
;;
*)
echo "No target !"
exit 255
;;
esac

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export PATH=$CUR/out/bin:$PATH

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -I/usr/local/include  @$CUR/gccflags -ffunction-sections -fdata-sections -flto-compression-level=1 -flto=2 -frandom-seed=1"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L/usr/local/lib @$CUR/ldflags"
export AR="gcc-ar"
export RANLIB="gcc-ranlib"
export NM="gcc-nm"

echo current utc time 1 is $(date -u)

cd m_binutils; mkdir build; cd build

../configure --prefix=$CUR/out --target=$TARGET $ADDI --enable-64-bit-bfd --enable-nls --disable-rpath --disable-multilib --enable-install-libiberty --enable-threads=posix --enable-plugins --enable-deterministic-archives --disable-werror --enable-lto --with-system-zlib --with-zstd --disable-gdb --disable-gprof --disable-gprofng || exit 255
make -j2 all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true

echo current utc time 2 is $(date -u)

cd $CUR

cp -a musl/$BIT/. out/$TARGET/
ln -s . out/$TARGET/usr

cd m_gcc; mkdir build; cd build

export CFLAGS_FOR_TARGET="@$CUR/gccflagsma -ffunction-sections -fdata-sections"
export CXXFLAGS_FOR_TARGET="-fdeclone-ctor-dtor $CFLAGS_FOR_TARGET"
export LDFLAGS_FOR_TARGET="@$CUR/ldflagsma"

echo current utc time 3 is $(date -u)

../configure --prefix=$CUR/out --target=$TARGET --enable-checking=release --enable-libatomic --enable-threads --enable-graphite --enable-fully-dynamic-string --enable-libstdcxx-filesystem-ts --enable-libstdcxx-time --enable-lto --enable-plugin --enable-libgomp --disable-libssp --disable-multilib --disable-rpath --enable-nls --disable-werror --disable-symvers --with-gcc-major-version-only --enable-linker-build-id --disable-vtable-verify --enable-default-pie  --with-default-libstdcxx-abi=new  --disable-libstdcxx-debug --disable-libsanitizer --enable-languages=c,c++,lto || exit 255
make -j2 all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true

echo current utc time 4 is $(date -u)

cd $CUR

mv out $TARGET
tar -zcf $TARGET-cross.tgz $TARGET
ln -s $TARGET out || exit 0
