#!/bin/sh

CUR=$PWD

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
export LD_LIBRARY_PATH=/opt/newcc/lib
fi

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

curl -L "https://github.com/eebssk1/mingw-crt-build/releases/download/8265b59c/mingw-crt.tgz" | tar -zxf -

echo current utc time 1 is $(date -u)

cd m_binutils; mkdir build; cd build

../configure --prefix=$CUR/out --target=i686-w64-mingw32 --enable-64-bit-bfd --enable-nls --disable-rpath --disable-multilib --enable-install-libiberty  --enable-plugins --enable-deterministic-archives --disable-werror --enable-lto --with-system-zlib --with-zstd --disable-gdb --disable-gprof --disable-gprofng || exit 255
make -j2 all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true

echo current utc time 2 is $(date -u)

cd $CUR

cp -a mingw-crt/msvcrt32/. out/i686-w64-mingw32/
ln -s . out/i686-w64-mingw32/usr

cd m_gcc; mkdir build; cd build

export lt_cv_deplibs_check_method='pass_all'
export CPPFLAGS_FOR_TARGET="-DWIN32_LEAN_AND_MEAN -DCOM_NO_WINDOWS_H -Wl,--large-address-aware -fdata-sections @$CUR/gccflagsm"
export LDFLAGS_FOR_TARGET="@$CUR/ldflagsm"
export CFLAGS_FOR_TARGET="-Os -g1 -fPIC -DPIC"
export CXXFLAGS_FOR_TARGET="-Os -g1 -fPIC -DPIC"

echo current utc time 3 is $(date -u)

../configure --prefix=$CUR/out --target=i686-w64-mingw32 --enable-checking=release --with-local-prefix=$CUR/out/i686-w64-mingw32/local --with-arch=prescott --with-tune=skylake --with-gcc-major-version-only --with-default-libstdcxx-abi=new --disable-vtable-verify --enable-libatomic --enable-threads=posix --enable-plugin --enable-graphite --enable-fully-dynamic-string --enable-libstdcxx-filesystem-ts --enable-libstdcxx-time --disable-libstdcxx-pch --enable-lto --enable-libgomp --disable-multilib --disable-rpath --enable-nls --disable-werror --disable-symvers --disable-libstdcxx-debug --enable-languages=c,c++,lto --disable-sjlj-exceptions --with-dwarf2 || exit 255
make -j2 all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true

echo current utc time 4 is $(date -u)

cd $CUR

mv out i686-w64-mingw32

tar -zcf i686-w64-mingw32-cross.tgz i686-w64-mingw32
ln -s i686-w64-mingw32 out || exit 0
