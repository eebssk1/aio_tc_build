#!/bin/sh

CUR=$PWD

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
export LD_LIBRARY_PATH=/opt/newcc/lib
fi

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -flto-compression-level=7 -fprofile-partial-training -I/usr/local/include  @$CUR/gccflags -ffunction-sections -fdata-sections"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L/usr/local/lib @$CUR/ldflags"

export CFLAGS_FOR_TARGET="-fPIC -DPIC -O3 -g1 -fgraphite -fgraphite-identity -fipa-pta -flive-range-shrinkage -fschedule-insns -fsched-pressure -fsched-spec-load -ftree-lrs -fsched-stalled-insns=8 -fsched-stalled-insns-dep=12 -malign-data=cacheline -mrelax-cmpxchg-loop -ffunction-sections -fdata-sections  -march=ivybridge -mtune=broadwell"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"

export PATH=$CUR/out/bin:$PATH

cd m_binutils; mkdir build; cd build

echo current utc time 1 is $(date -u)

../configure --target=x86_64-linux-gnu --prefix=/usr --enable-gold --enable-pgo-build=lto --enable-nls --enable-plugins --enable-compressed-debug-sections=all --enable-checking=release --enable-new-dtags --enable-x86-used-note --enable-generate-build-notes --disable-gprofng --with-system-zlib --with-zstd || exit 255
make -j$(($N+4)) all MAKEINFO=true || exit 255

make -j install-strip DESTDIR=$CUR/tmp MAKEINFO=true

echo current utc time 2 is $(date -u)

cd $CUR

mv tmp/usr out
rm -rf tmp


find -L out -maxdepth 3 -type f -name 'ld' -exec cp --remove-destination -f ld-wrp "{}" \;
find -L out -maxdepth 3 -type f -name '*-ld' -exec cp --remove-destination -f ld-wrp "{}" \;
for a in $CUR/out/bin/*
do
b=$(basename $a)
c=$(echo $b | awk -F'-' '{print $NF}')
if [ ! -e $CUR/out/bin/$c ]; then
echo "Linking $CUR/out/bin/$c as $a ..."
ln $a $CUR/out/bin/$c
fi
done

cd m_gcc; mkdir build; cd build

export FORCE_GOLD=1

echo current utc time 3 is $(date -u)

if [ x$FULL_LTO = x ]; then
echo "2 stage LTO enabled !"
DED=-lean
fi

../configure --host=x86_64-linux-gnu --prefix=/usr --enable-version-specific-runtime-libs --enable-lto --disable-cet --disable-multilib --enable-libstdcxx-time --disable-libstdcxx-debug --enable-graphite --enable-__cxa_atexit --enable-threads --enable-languages=c,c++,lto --enable-gnu-indirect-function --enable-initfini-array --enable-gnu-unique-object --enable-plugin --enable-default-pie --with-gcc-major-version-only --enable-linker-build-id --with-default-libstdcxx-abi=new --enable-fully-dynamic-string --with-arch=haswell --with-tune=skylake --enable-checking=release --without-included-gettext --enable-clocale=gnu --with-build-config=bootstrap-lto$DED --with-system-zlib --enable-shared=libgcc,libgcov,libitm,libssp,libsanitizer || exit 255
if [ "x$1" = "xprofile" ]; then
make -j$(($N+4)) profiledbootstrap BOOT_CFLAGS="$CFLAGS" BOOT_CXXFLAGS="$CXXFLAGS" BOOT_LDFLAGS="$LDFLAGS" STAGE1_CFLAGS="$CFLAGS" STAGE1_CXXFLAGS="$CXXFLAGS" STAGE1_LDFLAGS="$LDFLAGS"  MAKEINFO=true || exit 255
else
make -j$(($N+4)) bootstrap BOOT_CFLAGS="$CFLAGS" BOOT_CXXFLAGS="$CXXFLAGS" BOOT_LDFLAGS="$LDFLAGS" STAGE1_CFLAGS="$CFLAGS" STAGE1_CXXFLAGS="$CXXFLAGS" STAGE1_LDFLAGS="$LDFLAGS"  MAKEINFO=true || exit 255
fi

make -j install-strip DESTDIR=$CUR/tmp MAKEINFO=true



echo current utc time 4 is $(date -u)

cd $CUR

cp -a tmp/usr/. out/

if [ ! -e $CUR/out/bin/cc ] || [ ! -e $CUR/out/bin/c++ ]; then
echo "Creating cc/c++ to overlap system compilers ..."
ln -f $CUR/out/bin/gcc $CUR/out/bin/cc
ln -f $CUR/out/bin/g++ $CUR/out/bin/c++
fi

echo "Linking shared libgcc to compiler path ..."
RLPATH=$(find -L $CUR/out -name libgcc.a | sed 's/libgcc.a//')
find -L $CUR/out -name libgcc_s.so* -exec ln "{}" $RLPATH \;

mv out x86_64-linux-gnu
tar -zcf x86_64-linux-gnu-native.tgz x86_64-linux-gnu
ln -s x86_64-linux-gnu out || exit 0

