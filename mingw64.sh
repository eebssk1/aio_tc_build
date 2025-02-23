#!/bin/sh

CUR=$PWD

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
export LD_LIBRARY_PATH=/opt/newcc/lib
fi

MLIB=1
TAC=ivybridge
if [ "x$1" = "xlegacy" ]; then
CFIX=_legacy
CFIX2=-legacy
TAC=westmere
MLIB=0
fi

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export PATH=$CUR/out/bin:$PATH

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -I/usr/local/include  @$CUR/gccflags -flto-compression-level=1 -flto=2 -frandom-seed=1"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L/usr/local/lib @$CUR/ldflags"
export AR="gcc-ar"
export RANLIB="gcc-ranlib"
export NM="gcc-nm"

curl -L "https://github.com/eebssk1/mingw-crt-build/releases/latest/download/mingw-crt.tgz" | tar -zxf -

echo current utc time 1 is $(date -u)
TMS=$(date +%s)

cd m_binutils; mkdir build; cd build

../configure --prefix=$CUR/out --target=x86_64-w64-mingw32 --enable-64-bit-bfd --enable-checking=release --enable-nls --disable-rpath --enable-install-libiberty --enable-plugins --enable-deterministic-archives --disable-werror --enable-lto --with-system-zlib --with-zstd --disable-gdb --disable-gprof --disable-gprofng || exit 255
make -j$(($N+2)) all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true
TMM=$(date +%s)

echo current utc time 2 is $(date -u)

cd $CUR

cp -a mingw-crt/ucrt64$CFIX2/. out/x86_64-w64-mingw32/
ln -s ./include out/x86_64-w64-mingw32/sys-include

if [ x$MLIB = x1 ]; then
echo multilib enabled ~.
MLPAR="--enable-multiarch --enable-multilib --with-arch-32=westmere --with-multilib-list=m32,m64 --with-abi=m64"
mkdir -p out/x86_64-w64-mingw32/lib/32
ln -s ./lib/32 out/x86_64-w64-mingw32/lib32
cp -a mingw-crt/msvcrt32/lib/. out/x86_64-w64-mingw32/lib32/
cp -a mingw-crt/msvcrt32/lib32/. out/x86_64-w64-mingw32/lib32/
else
MLPAR="--disable-multiarch --disable-multilib"
fi

cd m_gcc; mkdir build; cd build

export lt_cv_deplibs_check_method='pass_all'
export CPPFLAGS_FOR_TARGET="-DWIN32_LEAN_AND_MEAN -DCOM_NO_WINDOWS_H @$CUR/gccflags"
export LDFLAGS_FOR_TARGET="@$CUR/ldflagsm"
export CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"

echo current utc time 3 is $(date -u)

../configure --prefix=$CUR/out --target=x86_64-w64-mingw32 --enable-version-specific-runtime-libs --enable-checking=release --with-local-prefix=$CUR/out/x86_64-w64-mingw32/local  --with-arch=$TAC --with-tune=icelake-client --with-gcc-major-version-only --with-default-libstdcxx-abi=new --disable-cet --disable-vtable-verify --enable-plugin  --enable-libatomic --enable-threads=posix --enable-graphite --enable-fully-dynamic-string --enable-libstdcxx-filesystem-ts --enable-libstdcxx-time --disable-libstdcxx-pch --enable-lto --enable-libgomp --enable-libssp --enable-shared=libgcc,libstdc++,libgomp,libatomic $MLPAR --disable-rpath --enable-nls --disable-werror --disable-symvers --disable-libstdcxx-debug --enable-languages=c,c++,lto --disable-sjlj-exceptions --with-specs-file="$CUR/mingw64.specs" || exit 255
make -j$(($N+2)) all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true

echo current utc time 4 is $(date -u)
TME=$(date +%s)
TMT0=$((($TMM-$TMS)/60))
TMT1=$((($TME-$TMM)/60))
TMA=$(($TMT0+$TMT1))
echo "part 1 took $TMT0 min, part 2 took $TMT1 min, which sum to $TMA min together!"

cd $CUR

if [ $MLIB = 1 ]; then
echo "Copy multi-arch compability wrapper !"
cp -dr $CUR/mingw-32-wrapper/. out/bin/
fi

rm out/x86_64-w64-mingw32/sys-include

mv out x86_64-w64$CFIX-mingw32
tar -I 'bzip2 -9' -cf x86_64-w64$CFIX-mingw32-cross.tb2 x86_64-w64$CFIX-mingw32
ln -s x86_64-w64$CFIX-mingw32 out || exit 0
