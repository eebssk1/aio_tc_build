#!/bin/sh

CUR=$PWD

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
export LD_LIBRARY_PATH=/opt/newcc/lib
fi

wget https://github.com/eebssk1/aio_tc_build/releases/latest/download/x86_64-w64-mingw32-cross.tb2 || exit 255
tar --bzip -xf x86_64-w64-mingw32-cross.tb2
mv x86_64-w64-mingw32 x86_64-w64-mingw32-boot
rm x86_64-w64-mingw32-cross.tb2

export PATH=$CUR/x86_64-w64-mingw32-boot/bin:$PATH

tar --bzip -xf gcc-dep.tb2
rm gcc-dep.tb2

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 @$CUR/gccflags"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$CUR/gcc-dep/lib @$CUR/ldflagsm"
export CPPFLAGS="-I$CUR/gcc-dep/include"

curl -L "https://github.com/eebssk1/mingw-crt-build/releases/latest/download/mingw-crt.tgz" | tar -zxf - || exit 255

echo current utc time 1 is $(date -u)
TMS=$(date +%s)

cp -rf mingw-crt/ucrt64/lib/* $CUR/x86_64-w64-mingw32-boot/x86_64-w64-mingw32/lib/
cp -rf mingw-crt/msvcrt32/lib/* $CUR/x86_64-w64-mingw32-boot/x86_64-w64-mingw32/lib/32/

mkdir -p out/x86_64-w64-mingw32
cp -a mingw-crt/ucrt64/. out/x86_64-w64-mingw32/
mkdir -p out/x86_64-w64-mingw32/lib/32/bin
cp -a mingw-crt/msvcrt32/lib/.  out/x86_64-w64-mingw32/lib/32
cp -a mingw-crt/msvcrt32/bin/.  out/x86_64-w64-mingw32/lib/32/bin
cp -a $CUR/gcc-dep/lib/*.a out/x86_64-w64-mingw32/lib
mkdir out/bin
cp -a $CUR/gcc-dep/lib/*.dll out/bin

ln -s ./include out/x86_64-w64-mingw32/sys-include

cd m_binutils; mkdir build; cd build

../configure --prefix=$CUR/out --host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32 --program-prefix=x86_64-w64-mingw32- --with-sysroot=$CUR/out/x86_64-w64-mingw32 --enable-multilib --enable-64-bit-bfd --enable-checking=release --disable-nls --disable-rpath --enable-install-libiberty --enable-plugins --enable-deterministic-archives --with-system-zlib --with-zstd --disable-werror --enable-lto --disable-gdb --disable-gprof --disable-gprofng || exit 255
make -j$(($N+2)) all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true
TMM=$(date +%s)

echo current utc time 2 is $(date -u)

cd $CUR

cd m_gcc; mkdir build; cd build

export lt_cv_deplibs_check_method='pass_all'
export CPPFLAGS_FOR_TARGET="-DWIN32_LEAN_AND_MEAN -DCOM_NO_WINDOWS_H @$CUR/gccflags"
export LDFLAGS_FOR_TARGET="@$CUR/ldflagsm"
export CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"

echo current utc time 3 is $(date -u)

../configure --prefix=$CUR/out --host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32 --program-prefix=x86_64-w64-mingw32- --enable-version-specific-runtime-libs --enable-checking=release --with-local-prefix=$CUR/out/x86_64-w64-mingw32/local  --with-arch=ivybridge --with-tune=icelake-client --with-gcc-major-version-only --with-default-libstdcxx-abi=new --disable-cet --disable-vtable-verify --enable-plugin  --enable-libatomic --enable-threads=posix --enable-graphite --enable-fully-dynamic-string --enable-libstdcxx-filesystem-ts --enable-libstdcxx-time --disable-libstdcxx-pch --enable-lto --enable-libgomp --disable-libssp --disable-libvtv --enable-shared=libgcc,libstdc++,libgomp,libatomic --enable-multiarch --enable-multilib --with-arch-32=prescott --with-multilib-list=m32,m64 --with-abi=m64 --disable-rpath --disable-nls --disable-werror --disable-symvers --disable-libstdcxx-debug --disable-win32-registry --enable-languages=c,c++,lto --disable-sjlj-exceptions --with-specs-file="$CUR/mingw64.specs" || exit 255
make -j$(($N+2)) all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true

echo current utc time 4 is $(date -u)
TME=$(date +%s)
TMT0=$((($TMM-$TMS)/60))
TMT1=$((($TME-$TMM)/60))
TMA=$(($TMT0+$TMT1))
echo "part 1 took $TMT0 min, part 2 took $TMT1 min, which sum to $TMA min together!"

cd $CUR

rm out/x86_64-w64-mingw32/sys-include

mv out x86_64-w64-mingw32-indep
tar -hI 'bzip2 -9' -cf x86_64-w64-mingw32-cross_indep.tb2 x86_64-w64-mingw32-indep
exit 0
