#!/bin/sh

CUR=$PWD

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
export LD_LIBRARY_PATH=/opt/newcc/lib
fi

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -flto-compression-level=1 -fprofile-partial-training -I/usr/local/include  @$CUR/gccflags -ffunction-sections -fdata-sections"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L/usr/local/lib @$CUR/ldflags"

export PATH=$CUR/out/bin:$PATH

cd m_binutils; mkdir build; cd build

echo current utc time 1 is $(date -u)

../configure --prefix=/usr --enable-gold --enable-pgo-build=lto --enable-nls --enable-plugins --enable-new-dtags --enable-x86-used-note --enable-generate-build-notes --disable-gprofng --with-system-zlib --with-zstd || exit 255
make -j4 all MAKEINFO=true || exit 255

make -j3 install-strip DESTDIR=$CUR/tmp MAKEINFO=true

echo current utc time 2 is $(date -u)

cd $CUR

mv tmp/usr out
rm -rf tmp

cp --remove-destination -f ld-wrp $CUR/out/bin/ld
cp --remove-destination -f ld-wrp $CUR/out/x86*/bin/ld

cd m_gcc; mkdir build; cd build

export FORCE_GOLD=1

echo current utc time 3 is $(date -u)

export CFLAGS_FOR_TARGET="-fPIC -DPIC -Os -g1"
export CXXFLAGS_FOR_TARGET="-fPIC -DPIC -Os -g1"

../configure --prefix=/usr --enable-lto --disable-multilib --enable-libstdcxx-time --disable-libstdcxx-debug --enable-graphite --enable-__cxa_atexit --enable-threads --enable-languages=c,c++,lto --enable-gnu-indirect-function --enable-initfini-array --enable-gnu-unique-object --enable-plugin --enable-default-pie --with-gcc-major-version-only --enable-linker-build-id --with-default-libstdcxx-abi=new --enable-fully-dynamic-string --with-arch=haswell --with-tune=skylake --enable-checking=release --without-included-gettext --enable-clocale=gnu --with-build-config=bootstrap-lto-lean --with-system-zlib --disable-shared|| exit 255
if [ "x$1" = "xprofile" ]; then
make -j4 profiledbootstrap BOOT_CFLAGS="$CFLAGS" BOOT_CXXFLAGS="$CXXFLAGS" BOOT_LDFLAGS="$LDFLAGS" STAGE1_CFLAGS="$CFLAGS" STAGE1_CXXFLAGS="$CXXFLAGS" STAGE1_LDFLAGS="$LDFLAGS"  MAKEINFO=true || exit 255
else
make -j4 bootstrap BOOT_CFLAGS="$CFLAGS" BOOT_CXXFLAGS="$CXXFLAGS" BOOT_LDFLAGS="$LDFLAGS" STAGE1_CFLAGS="$CFLAGS" STAGE1_CXXFLAGS="$CXXFLAGS" STAGE1_LDFLAGS="$LDFLAGS"  MAKEINFO=true || exit 255
fi

make -j3 install-strip DESTDIR=$CUR/tmp MAKEINFO=true

echo current utc time 4 is $(date -u)

cd $CUR

cp -a tmp/usr/. out/

mv out x86_64-linux-gnu
tar -zcf x86_64-linux-gnu-native.tgz x86_64-linux-gnu
ln -s x86_64-linux-gnu out || exit 0
