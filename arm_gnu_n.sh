#!/bin/sh

CUR=$PWD

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
export LD_LIBRARY_PATH=/opt/newcc/lib
fi

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -D__BUILD_NO_CON__ -flto-compression-level=1 -fprofile-partial-training -I/usr/local/include  @$CUR/gccflagsa -Wno-error=maybe-uninitialized"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L/usr/local/lib @$CUR/ldflagsa"

export CFLAGS_FOR_TARGET="-D__BUILD_NO_CON__ -ffunction-sections -fdata-sections @$CUR/gccflagsa -Wno-error=maybe-uninitialized"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"
export LDFLAGS_FOR_TARGET="@$CUR/ldflagsa"

export PATH=$CUR/out/bin:$PATH

rm -r /opt/newcc

curl -L "https://github.com/eebssk1/aio_tc_build/releases/latest/download/aarch64-linux-gnu-native.tb2" | tar --bz -xf -
mv aarch64-linux-gnu /opt/newcc

apt-get install -y libc6-dev-arm64-cross

hash -r

cd m_binutils; mkdir build; cd build

echo current utc time 1 is $(date -u)
TMS=$(date +%s)

../configure --target=aarch64-linux-gnu --prefix=/usr --enable-pgo-build=lto --enable-nls --enable-plugins --disable-multilib --enable-compressed-debug-sections=all --enable-checking=release --enable-new-dtags --disable-gdb --disable-gdbserver --disable-sim --disable-gprof --disable-gprofng --with-system-zlib --with-zstd || exit 255
make -j$(($N+4)) all MAKEINFO=true || exit 255

make -j install-strip DESTDIR=$CUR/tmp MAKEINFO=true

echo current utc time 2 is $(date -u)
TMM=$(date +%s)

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

echo current utc time 3 is $(date -u)

if [ x$FULL_LTO = x ]; then
echo "2 stage LTO disabled !"
DED=-lean
fi

if [ x$NO_LTO = x ]; then
LTO="--with-build-config=bootstrap-lto$DED"
fi

../configure --host=aarch64-linux-gnu --build=aarch64-linux-gnu --target=aarch64-linux-gnu --prefix=/usr --enable-version-specific-runtime-libs --enable-lto --disable-cet --disable-multiarch --disable-multilib --disable-fixincludes --enable-libstdcxx-time --disable-libstdcxx-debug --disable-libstdcxx-pch --enable-graphite --enable-threads --enable-languages=c,c++,lto --with-linker-hash-style=gnu --enable-gnu-indirect-function --enable-gnu-unique-object --enable-plugin --enable-default-pie --with-gcc-major-version-only --enable-linker-build-id --with-default-libstdcxx-abi=new --enable-fully-dynamic-string --with-arch=armv8.2-a --with-tune=cortex-a76.cortex-a55 --enable-checking=release --without-included-gettext --enable-clocale=gnu $LTO --with-system-zlib --enable-shared=libgcc,libstdc++,libitm,libssp,libsanitizer --with-specs-file="$CUR/arm.specs" || exit 255
if [ "x$1" = "xprofile" ]; then
make -j$(($N+4)) profiledbootstrap BOOT_CFLAGS="$CFLAGS" BOOT_CXXFLAGS="$CXXFLAGS" BOOT_LDFLAGS="$LDFLAGS" STAGE1_CFLAGS="$CFLAGS" STAGE1_CXXFLAGS="$CXXFLAGS" STAGE1_LDFLAGS="$LDFLAGS"  MAKEINFO=true || exit 255
else
make -j$(($N+4)) bootstrap BOOT_CFLAGS="$CFLAGS" BOOT_CXXFLAGS="$CXXFLAGS" BOOT_LDFLAGS="$LDFLAGS" STAGE1_CFLAGS="$CFLAGS" STAGE1_CXXFLAGS="$CXXFLAGS" STAGE1_LDFLAGS="$LDFLAGS"  MAKEINFO=true || exit 255
fi

make -j install-strip DESTDIR=$CUR/tmp MAKEINFO=true

GCV=$(cat ../gcc/BASE-VER | cut -d'.' -f 1)

cd $CUR/tmp/bin

for a in cpp g++ gcc gcc-ar gcc-nm gcc-ranlib gcov
do
TA=${a}-${GCV}
TB=x86_64-linux-gnu-${a}
if [ -e $a ] && [ ! -e ${TA} ]; then
ln -s ${a} ${TA}
fi
if [ -e ${TB} ] && [ ! -e ${TB}-${GCV} ]; then
ln -s ${TB} ${TB}-${GCV}
fi
done

echo current utc time 4 is $(date -u)
TME=$(date +%s)
cd $CUR

cp -a tmp/usr/. out/

if [ ! -e $CUR/out/bin/cc ] || [ ! -e $CUR/out/bin/c++ ]; then
echo "Creating cc/c++ to overlap system compilers ..."
ln -f $CUR/out/bin/gcc $CUR/out/bin/cc
ln -f $CUR/out/bin/g++ $CUR/out/bin/c++
fi

TMT0=$((($TMM-$TMS)/60))
TMT1=$((($TME-$TMM)/60))
TMA=$(($TMT0+$TMT1))
echo "part 1 took $TMT0 min, part 2 took $TMT1 min, which sum to $TMA min together!"

mv out aarch64-linux-gnu
tar -I 'bzip2 -9' -cf aarch64-linux-gnu-native.tb2 aarch64-linux-gnu
ln -s aarch64-linux-gnu out || exit 0

