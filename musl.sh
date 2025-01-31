#!/bin/sh

CUR=$PWD

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
export LD_LIBRARY_PATH=/opt/newcc/lib
fi

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -flto-compression-level=1 -fprofile-partial-training -flto=2 -frandom-seed=1 -I/usr/local/include  @$CUR/gccflags -Wno-error=maybe-uninitialized"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L/usr/local/lib @$CUR/ldflags"

export CFLAGS_FOR_TARGET="-DPIC -fPIC -ffunction-sections -fdata-sections @$CUR/gccflags -Wno-error=maybe-uninitialized"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"

#export PATH=$CUR/out/bin:$PATH

mkdir -p out/x86_64-linux-musl
tar -zxf musl_libc_amd64.tgz
cp -a musl-libc/. out/x86_64-linux-musl/
ln -s ./include out/x86_64-linux-musl/sys-include

cd m_binutils; mkdir build; cd build

echo current utc time 1 is $(date -u)
TMS=$(date +%s)

../configure --target=x86_64-linux-musl --prefix=$CUR/out --enable-gold --enable-nls --enable-plugins --enable-compressed-debug-sections=all --enable-checking=release --enable-deterministic-archives --enable-new-dtags --disable-gprofng --with-system-zlib --with-zstd || exit 255
make -j$(($N+4)) all MAKEINFO=true || exit 255

make -j install-strip MAKEINFO=true

echo current utc time 2 is $(date -u)
TMM=$(date +%s)

cd $CUR

find -L out -maxdepth 3 -type f -name 'ld' -exec cp --remove-destination -f ld-wrp "{}" \;
find -L out -maxdepth 3 -type f -name '*-ld' -exec cp --remove-destination -f ld-wrp "{}" \;

cd m_gcc; mkdir build; cd build

echo current utc time 3 is $(date -u)

../configure --host=x86_64-linux-gnu --build=x86_64-linux-gnu --target=x86_64-linux-musl --prefix=$CUR/out --enable-tls --disable-multilib --disable-multiarch --enable-version-specific-runtime-libs --enable-lto --disable-cet --disable-libvtv --disable-fixincludes --enable-libstdcxx-time=rt --disable-libstdcxx-debug --disable-libstdcxx-pch --enable-graphite --enable-__cxa_atexit --enable-threads --enable-languages=c,c++,lto --with-linker-hash-style=gnu --enable-gnu-indirect-function --enable-initfini-array --enable-gnu-unique-object --enable-plugin --enable-default-pie --enable-libssp --enable-default-ssp --with-gcc-major-version-only --enable-linker-build-id --with-default-libstdcxx-abi=new --enable-fully-dynamic-string --with-arch=ivybridge --with-tune=broadwell --enable-checking=release --without-included-gettext --enable-clocale=gnu --with-system-zlib --disable-libsanitizer --enable-libgcov --enable-shared=libgcc,libstdc++,libgomp --with-specs-file="$CUR/musl.specs" || exit 255
make -j$(($N+4)) || exit 255
make -j install-strip MAKEINFO=true

echo current utc time 4 is $(date -u)
TME=$(date +%s)
cd $CUR

TMT0=$((($TMM-$TMS)/60))
TMT1=$((($TME-$TMM)/60))
TMA=$(($TMT0+$TMT1))
echo "part 1 took $TMT0 min, part 2 took $TMT1 min, which sum to $TMA min together!"

rm out/x86_64-linux-musl/sys-include

mv out x86_64-linux-musl
tar -I 'bzip2 -9' -cf x86_64-linux-musl-cross.tb2 x86_64-linux-musl
ln -s x86_64-linux-musl out || exit 0

