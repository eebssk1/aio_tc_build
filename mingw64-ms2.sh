#!/bin/sh

CUR=$PWD

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -march=ivybridge -mtune=broadwell @$CUR/gccflags"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="@$CUR/ldflagsm"

curl -L "https://github.com/eebssk1/mingw-crt-build/releases/latest/download/mingw-crt.tgz" | tar -zxf - || exit 255


echo current utc time 1 is $(date -u)
TMS=$(date +%s)

cd mingw-w64-mingw-w64; mkdir build; cd build

../configure --without-headers --without-crt --with-tools=all --prefix=$CUR/out || exit 255
make -j$(($N+3)) all MAKEINFO=true || exit 255
make -j install-strip MAKEINFO=true

cd $CUR

cd m_binutils; mkdir build; cd build

../configure --prefix=${MINGW_PREFIX} --target=x86_64-w64-mingw32 --enable-64-bit-bfd --enable-checking=release --disable-multilib --disable-nls --disable-rpath --with-libiconv-prefix=${MINGW_PREFIX} --with-sysroot=${MINGW_PREFIX} --enable-install-libiberty --enable-plugins --enable-deterministic-archives --disable-werror --enable-lto --with-system-zlib --with-zstd --disable-gdb --disable-gprof --disable-gprofng || exit 255
make -j$(($N+3)) all MAKEINFO=true || exit 255

make -j install-strip prefix=$CUR/out MAKEINFO=true
TMM=$(date +%s)

echo current utc time 2 is $(date -u)

cd $CUR

#not required under msys2?
#tar --bzip -xf gcc-dep.tb2
#cp -a gcc-dep/lib/*.a out/x86_64-w64-mingw32/lib/
#cp -a gcc-dep/lib/*.dll out/bin/

cp -a mingw-crt/ucrt64/. out/x86_64-w64-mingw32/

cd m_gcc; mkdir build; cd build

export lt_cv_deplibs_check_method='pass_all'
export CPPFLAGS_FOR_TARGET="-DWIN32_LEAN_AND_MEAN -DCOM_NO_WINDOWS_H @$CUR/gccflags"
export LDFLAGS_FOR_TARGET="@$CUR/ldflagsm"
export CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"

echo current utc time 3 is $(date -u)

../configure --prefix=$CUR/out --target=x86_64-w64-mingw32 --enable-bootstrap --with-build-config=bootstrap-O3 --enable-version-specific-runtime-libs --enable-checking=release --with-local-prefix=$CUR/out/x86_64-w64-mingw32/local --with-native-system-header-dir=/ucrt64/include --with-arch=haswell --with-tune=skylake --with-gcc-major-version-only --with-default-libstdcxx-abi=new --disable-cet --disable-vtable-verify --enable-plugin  --with-system-zlib --enable-libatomic --enable-threads=posix --enable-graphite --enable-fully-dynamic-string --enable-libstdcxx-filesystem-ts --enable-libstdcxx-time --disable-libstdcxx-pch --enable-lto --enable-libgomp --disable-libssp --disable-libvtv --enable-shared=libgcc,libstdc++,libgomp,libatomic --disable-multiarch --disable-multilib --disable-rpath --disable-nls --disable-werror --disable-symvers --disable-libstdcxx-debug --disable-win32-registry --enable-languages=c,c++,lto --disable-sjlj-exceptions --with-specs-file="$CUR/mingw64.specs" || exit 255
make -j$(($N+3)) bootstrap STAGE1_CFLAGS="-g1 -Os" MAKEINFO=true || exit 255
make -j$(($N+3)) all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true

echo current utc time 4 is $(date -u)
TME=$(date +%s)
TMT0=$((($TMM-$TMS)/60))
TMT1=$((($TME-$TMM)/60))
TMA=$(($TMT0+$TMT1))
echo "part 1 took $TMT0 min, part 2 took $TMT1 min, which sum to $TMA min together!"

cd $CUR

mv out x86_64-w64-mingw32-msys2
tar -I 'bzip2 -9' -cf x86_64-w64-mingw32-cross_msys2.tb2 x86_64-w64-mingw32-msys2

exit 0

