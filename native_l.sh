#!/bin/sh

CUR=$PWD

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
export LD_LIBRARY_PATH=/opt/newcc/lib
fi

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -I/usr/local/include  @$CUR/gccflags -Wno-error=maybe-uninitialized"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L/usr/local/lib @$CUR/ldflags"

export CFLAGS_FOR_TARGET="-DPIC -fPIC -ffunction-sections -fdata-sections @$CUR/gccflags -Wno-error=maybe-uninitialized"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"

export PATH=$CUR/out/bin:$PATH

cd m_binutils; mkdir build; cd build

echo current utc time 1 is $(date -u)
TMS=$(date +%s)

../configure --target=x86_64-linux-gnu --prefix=/usr --enable-nls --enable-plugins --enable-multilib --enable-compressed-debug-sections=all --enable-checking=release --enable-new-dtags --disable-gprofng --with-system-zlib --with-zstd || exit 255
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

../configure --host=x86_64-linux-gnu --build=x86_64-linux-gnu --target=x86_64-linux-gnu --prefix=/usr --enable-version-specific-runtime-libs --enable-lto --disable-cet --enable-multiarch --with-arch-32=westmere --enable-multilib --with-multilib-list=m32,m64,mx32 --with-abi=m64 --disable-fixincludes --enable-libstdcxx-time --disable-libstdcxx-debug --disable-libstdcxx-pch --enable-graphite --enable-__cxa_atexit --enable-threads --enable-languages=c,c++,lto --with-linker-hash-style=gnu --enable-gnu-indirect-function --enable-initfini-array --enable-gnu-unique-object --enable-plugin --enable-default-pie --with-gcc-major-version-only --enable-linker-build-id --with-default-libstdcxx-abi=new --enable-fully-dynamic-string --with-arch=ivybridge --with-tune=broadwell --enable-checking=release --without-included-gettext --enable-clocale=gnu --with-system-zlib --enable-shared=libgcc,libgcov,libitm,libssp,libsanitizer --with-specs-file="$CUR/native.specs" || exit 255
make -j$(($N+4)) bootstrap BOOT_CFLAGS="$CFLAGS" BOOT_CXXFLAGS="$CXXFLAGS" BOOT_LDFLAGS="$LDFLAGS" STAGE1_CFLAGS="$CFLAGS" STAGE1_CXXFLAGS="$CXXFLAGS" STAGE1_LDFLAGS="$LDFLAGS"  MAKEINFO=true || exit 255

make -j install-strip DESTDIR=$CUR/tmp MAKEINFO=true


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

mv out x86_64-linux-gnu_l
tar -I 'bzip2 -9' -cf x86_64-linux-gnu-native_l.tb2 x86_64-linux-gnu_l
ln -s x86_64-linux-gnu_l out || exit 0

