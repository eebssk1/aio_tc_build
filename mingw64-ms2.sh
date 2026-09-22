#!/bin/bash

CUR=$PWD

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -D__BUILD_NO_CON__ -Wa,-O2 -march=ivybridge -mtune=broadwell @$CUR/gccflags"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="@$CUR/ldflagsm"

curl -L "https://github.com/eebssk1/mingw-crt-build/releases/latest/download/mingw-crt.tgz" | tar -zxf - || exit 255


echo current utc time 1 is $(date -u)
TMS=$(date +%s)

cd mingw-w64-mingw-w64; mkdir build; cd build

../configure --without-headers --without-crt --with-tools=all --prefix=$CUR/out || exit 255
make -j$(($N+3)) all MAKEINFO=true || exit 255
make -j install-strip MAKEINFO=true || exit 255

cd $CUR

if [ "x$MS" != "x" ]; then
SUF="_ms"
fi

mv mingw-crt/ucrt64${SUF}/bin/*.dll mingw-crt/ucrt64${SUF}/lib*/ || true
cp -a mingw-crt/ucrt64${SUF}/. out/x86_64-w64-mingw32/ || exit 255

cd m_binutils; mkdir build; cd build

export LDFLAGS="$LDFLAGS -L${PWD}/libiberty"

../configure --prefix=${MINGW_PREFIX} --target=x86_64-w64-mingw32 --enable-64-bit-bfd --disable-multilib --disable-shared --enable-nls --disable-rpath --with-libiconv-prefix=${MINGW_PREFIX} --with-sysroot=${MINGW_PREFIX} --enable-install-libiberty --enable-plugins --enable-deterministic-archives --disable-werror --enable-lto --with-system-zlib --with-zstd --disable-gdb --disable-gdbserver --disable-gprof --disable-gprofng || exit 255
make -j$(($N+3)) all MAKEINFO=true || exit 255

make -j install-strip prefix=$CUR/out MAKEINFO=true || exit 255
TMM=$(date +%s)

echo current utc time 2 is $(date -u)

# A native MinGW collect2.exe prefers real-ld.exe from its -B search path over
# GCC's build-tree collect-ld shell wrapper.  The latter crosses from a native
# process into MSYS /bin/sh and back into the native linker; that bridge can
# return 127 without preserving the shell/loader diagnostic.  Keep this alias
# bootstrap-only so the installed compiler remains relocatable and continues
# to use its normal target-prefixed linker lookup.
BOOTSTRAP_REAL_LD=$CUR/out/x86_64-w64-mingw32/bin/real-ld.exe
BOOTSTRAP_LD=$CUR/out/x86_64-w64-mingw32/bin/ld.exe
rm -f "$BOOTSTRAP_REAL_LD"
ln "$BOOTSTRAP_LD" "$BOOTSTRAP_REAL_LD" 2>/dev/null || cp -p "$BOOTSTRAP_LD" "$BOOTSTRAP_REAL_LD" || exit 255
test -x "$BOOTSTRAP_REAL_LD" || exit 255
"$BOOTSTRAP_REAL_LD" --version >/dev/null || exit 255

cd $CUR

cd m_gcc; mkdir build; cd build

cd ..
for F in Makefile.in Makefile.tpl
do
grep -q -- '$(SYSROOT_CFLAGS_FOR_TARGET)' "$F" || exit 255
grep -q -- 'GCC_FOR_TARGET=$(STAGE_CC_WRAPPER) @GCC_FOR_TARGET@' "$F" || exit 255
grep -Fq -- '`if $(LEAN); then echo '\'' -isystem '\''; else echo '\'' -I'\''; fi`$$s/libstdc++-v3/libsupc++ \' "$F" || exit 255
sed -i '/`if $(LEAN); then echo '\'' -isystem '\''; else echo '\'' -I'\''; fi`\$\$s\/libstdc++-v3\/libsupc++ \\/a\	  $(SYSROOT_CFLAGS_FOR_TARGET) \\' "$F" || exit 255
sed -i 's#GCC_FOR_TARGET=$(STAGE_CC_WRAPPER) @GCC_FOR_TARGET@#GCC_FOR_TARGET=$(STAGE_CC_WRAPPER) @GCC_FOR_TARGET@ $(SYSROOT_CFLAGS_FOR_TARGET)#' "$F" || exit 255
done
cd build

export lt_cv_deplibs_check_method='pass_all'
export gcc_cv_have_tls=yes
export glibcxx_cv_atomic_word=yes
export CPPFLAGS_FOR_TARGET="-DWIN32_LEAN_AND_MEAN -DCOM_NO_WINDOWS_H @$CUR/gccflags"
export LDFLAGS_FOR_TARGET="@$CUR/ldflagsm"
export CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections -Wa,-O2 -D__BUILD_NO_CON__"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"

echo current utc time 3 is $(date -u)

../configure --prefix=$CUR/out --target=x86_64-w64-mingw32 --with-sysroot=$CUR/out/x86_64-w64-mingw32 --with-build-sysroot=$(cygpath -am $CUR/out/x86_64-w64-mingw32) --enable-bootstrap --with-build-config=bootstrap-O3 --enable-mingw-wildcard --enable-version-specific-runtime-libs --enable-checking=release --with-local-prefix=/local --with-native-system-header-dir=/include --with-arch=haswell --with-tune=skylake --with-gcc-major-version-only --enable-tls --disable-cet --disable-vtable-verify --enable-plugin  --with-system-zlib --enable-libatomic --enable-threads=posix --enable-graphite --enable-fully-dynamic-string --enable-libstdcxx-filesystem-ts --enable-libstdcxx-time --disable-libstdcxx-pch --enable-libstdcxx-backtrace=yes --with-libstdcxx-zoneinfo="yes" --enable-lto --enable-libgomp --disable-libssp --disable-libvtv --enable-shared=libgcc,libstdc++,libgomp,libatomic --disable-multiarch --disable-multilib --disable-rpath --disable-nls --disable-werror --disable-symvers --disable-libstdcxx-debug --disable-win32-registry --enable-languages=c,c++,lto --disable-sjlj-exceptions --with-specs-file="$CUR/mingw64.specs" || exit 255
export CPATH="$CUR/out/x86_64-w64-mingw32/include${CPATH:+:$CPATH}"
export LIBRARY_PATH="$CUR/out/x86_64-w64-mingw32/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
export MSYS2_ARG_CONV_EXCL="-D"
GCC_BUILD_LOG="$CUR/gcc-bootstrap.log"
GCC_FAILURE_LOG="$CUR/gcc-bootstrap-failure.log"
rm -f "$GCC_BUILD_LOG" "$GCC_FAILURE_LOG"
{
make -j$(($N+3)) bootstrap STAGE1_CFLAGS="-g1 -Os" MAKEINFO=true && make -j$(($N+3)) all MAKEINFO=true
} 2>&1 | tee "$GCC_BUILD_LOG"
GCC_BUILD_STATUS=${PIPESTATUS[0]}

if [ "$GCC_BUILD_STATUS" != "0" ]; then
tail -n 4000 "$GCC_BUILD_LOG" > "$GCC_FAILURE_LOG" || true
echo "Error ed !"
exit 255
fi

rm -f "$BOOTSTRAP_REAL_LD" || exit 255
make -j install-strip MAKEINFO=true || exit 255

GCV=$(cat ../gcc/BASE-VER | cut -d'.' -f 1)

cd $CUR/out/bin

for a in cpp g++ gcc gcc-ar gcc-nm gcc-ranlib gcov
do
TA=${a}-${GCV}
TB=x86_64-w64-mingw32-${a}
if [ -e $a ] && [ ! -e ${TA} ]; then
ln -s ${a} ${TA}
fi
if [ -e ${TB} ] && [ ! -e ${TB}-${GCV} ]; then
ln -s ${TB} ${TB}-${GCV}
fi
done

echo current utc time 4 is $(date -u)
TME=$(date +%s)
TMT0=$((($TMM-$TMS)/60))
TMT1=$((($TME-$TMM)/60))
TMA=$(($TMT0+$TMT1))
echo "part 1 took $TMT0 min, part 2 took $TMT1 min, which sum to $TMA min together!"

cd $CUR

mv out x86_64-w64-mingw32-msys2$SUF || exit 255
tar -I 'bzip2 -9' -cf x86_64-w64-mingw32-cross_msys2$SUF.tb2 x86_64-w64-mingw32-msys2$SUF || exit 255

exit 0
