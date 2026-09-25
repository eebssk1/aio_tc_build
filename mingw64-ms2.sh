#!/bin/bash

CUR=$PWD

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc" CXX="ccache g++"
fi

export CFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -D__BUILD_NO_CON__ -Wa,-O2 -march=ivybridge -mtune=broadwell @$CUR/gccflags"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="@$CUR/ldflagsm"

MINGW_CRT_RELEASE=${MINGW_CRT_RELEASE:-d8d4c2f9}
MINGW_CRT_SHA256=${MINGW_CRT_SHA256:-0bface6371783b7da5d280b8d1d786e4f9155199374cc7825c4a033e4d393cba}
MINGW_CRT_ARCHIVE=$CUR/mingw-crt.tgz
curl --fail --location --retry 3 --output "$MINGW_CRT_ARCHIVE" \
  "https://github.com/eebssk1/mingw-crt-build/releases/download/$MINGW_CRT_RELEASE/mingw-crt.tgz" || exit 255
printf '%s  %s\n' "$MINGW_CRT_SHA256" "$MINGW_CRT_ARCHIVE" | sha256sum --check || exit 255
tar -zxf "$MINGW_CRT_ARCHIVE" || exit 255
rm -f "$MINGW_CRT_ARCHIVE" || exit 255


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
# MinGW libiberty otherwise truncates the 32-bit Windows process status to
# eight bits before collect2 reports it.  Preserve the normal wait status, but
# print the full value for abnormal statuses (for example 0xc0000374 becomes
# the otherwise ambiguous "ld returned 116 exit status").
PEX_WIN32=libiberty/pex-win32.c
grep -Fq 'GetExitCodeProcess (h, &termstat);' "$PEX_WIN32" || exit 255
if ! sed -n '1,100p' "$PEX_WIN32" | grep -Fq '#include <stdio.h>'; then
sed -i '/#include <signal.h>/a#include <stdio.h>' "$PEX_WIN32" || exit 255
fi
if ! grep -Fq 'child Windows status 0x%08lx' "$PEX_WIN32"; then
sed -i '/  GetExitCodeProcess (h, &termstat);/a\
  if ((termstat & ~0xffU) != 0)\
    fprintf (stderr, "pex-win32: child Windows status 0x%08lx\\n",\
             (unsigned long) termstat);' "$PEX_WIN32" || exit 255
fi
sed -n '1,100p' "$PEX_WIN32" | grep -Fq '#include <stdio.h>' || exit 255
grep -Fq 'child Windows status 0x%08lx' "$PEX_WIN32" || exit 255

# Unlike the generic shared-libgcc fragments, the MinGW fragment does not put
# $(LDFLAGS) in SHLIB_LINK.  Without it, LDFLAGS_FOR_TARGET reaches configure
# probes but not the actual libgcc_s DLL link, so the bootstrap-only plugin
# isolation configured below is silently lost at the failing link.  Mirror GCC
# upstream commit 0636b7763dca11f9637e3177086fc7f5355773a5 exactly; also migrate
# the equivalent interim placement used by an earlier version of this script.
MINGW_SHLIB=libgcc/config/i386/t-slibgcc-cygming
if ! grep -Fq -- '-shared -nodefaultlibs $(LDFLAGS) \' "$MINGW_SHLIB"; then
if grep -Fq -- '$(CC) $(LIBGCC2_CFLAGS) $(LDFLAGS) $(SHLIB_PTHREAD_CFLAG) \' "$MINGW_SHLIB"; then
sed -i 's/$(CC) $(LIBGCC2_CFLAGS) $(LDFLAGS) $(SHLIB_PTHREAD_CFLAG) \\/$(CC) $(LIBGCC2_CFLAGS) $(SHLIB_PTHREAD_CFLAG) \\/' "$MINGW_SHLIB" || exit 255
fi
grep -Fq -- '-shared -nodefaultlibs \' "$MINGW_SHLIB" || exit 255
sed -i 's/-shared -nodefaultlibs \\/-shared -nodefaultlibs $(LDFLAGS) \\/' "$MINGW_SHLIB" || exit 255
fi
grep -Fq -- '-shared -nodefaultlibs $(LDFLAGS) \' "$MINGW_SHLIB" || exit 255

# The MinGW UTF-8 manifest fragment performs a separate relocatable link with
# $(COMPILER), bypassing the normal GCC link recipes.  In stage 2 this silently
# re-enables the unverified linker plugin and triggers the same native ld heap
# corruption.  Do not propagate all LDFLAGS: the stage 1 flags include
# --relax, which PE ld rejects together with -r.  Disable only the problematic
# plugin path; this changes neither installed specs nor ordinary final links.
MINGW_UTF8=gcc/config/i386/x-mingw32-utf8
if grep -Fq -- '$(COMPILER) $(LDFLAGS) -r -nostdlib utf8rc-mingw32.o sym-mingw32.o -o $@' "$MINGW_UTF8"; then
sed -i 's/$(COMPILER) $(LDFLAGS) -r -nostdlib utf8rc-mingw32.o sym-mingw32.o -o $@/$(COMPILER) -fno-use-linker-plugin -r -nostdlib utf8rc-mingw32.o sym-mingw32.o -o $@/' "$MINGW_UTF8" || exit 255
fi
if ! grep -Fq -- '$(COMPILER) -fno-use-linker-plugin -r -nostdlib utf8rc-mingw32.o sym-mingw32.o -o $@' "$MINGW_UTF8"; then
grep -Fq -- '$(COMPILER) -r -nostdlib utf8rc-mingw32.o sym-mingw32.o -o $@' "$MINGW_UTF8" || exit 255
sed -i 's/$(COMPILER) -r -nostdlib utf8rc-mingw32.o sym-mingw32.o -o $@/$(COMPILER) -fno-use-linker-plugin -r -nostdlib utf8rc-mingw32.o sym-mingw32.o -o $@/' "$MINGW_UTF8" || exit 255
fi
grep -Fq -- '$(COMPILER) -fno-use-linker-plugin -r -nostdlib utf8rc-mingw32.o sym-mingw32.o -o $@' "$MINGW_UTF8" || exit 255

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
# HAVE_LTO_PLUGIN=2 is inferred from the GNU ld version rather than from a
# successful plugin load.  The failing ordinary stage1 target links therefore
# load the just-built liblto_plugin.dll even without LTO input.  Isolate that
# unverified path during bootstrap; the installed compiler keeps its normal
# plugin defaults and explicit LTO support.  Keep the driver option in the same
# response file as the linker flags because libtool drops unknown bare driver
# options while rewriting shared-library links, but preserves @response files.
BOOTSTRAP_TARGET_LDFLAGS=$CUR/ldflagsm-bootstrap
cat "$CUR/ldflagsm" > "$BOOTSTRAP_TARGET_LDFLAGS" || exit 255
printf '\n-fno-use-linker-plugin\n' >> "$BOOTSTRAP_TARGET_LDFLAGS" || exit 255
grep -Fxq -- '-fno-use-linker-plugin' "$BOOTSTRAP_TARGET_LDFLAGS" || exit 255
export LDFLAGS_FOR_TARGET="@$BOOTSTRAP_TARGET_LDFLAGS"
export CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections -Wa,-O2 -D__BUILD_NO_CON__"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"

# Stage 1 finds these native host dependencies through the system compiler's
# implicit prefix, but prev-gcc uses the freshly populated target sysroot in
# stage 2.  Fail early if setup-msys2 ever stops providing their development
# files; otherwise missing GMP headers corrupt declaration probes, while a
# missing zlib is only reported when stage 2 links gcov.
for HEADER in gmp.h mpfr.h mpc.h isl/ctx.h zlib.h zstd.h
do
test -f "$MINGW_PREFIX/include/$HEADER" || exit 255
done
compgen -G "$MINGW_PREFIX/lib/libz.*" >/dev/null || exit 255
compgen -G "$MINGW_PREFIX/lib/libzstd.*" >/dev/null || exit 255

# POSTSTAGE1_LDFLAGS is exported as LDFLAGS to stage 2 and later host modules.
# Keep libstdc++ static, but follow the official MSYS2 GCC build and leave
# libgcc dynamic.  Native GMP/zlib/zstd can already load the host libgcc DLL,
# so a second static libgcc copy in a host module is unsafe.  The native
# linker/plugin cross-test also isolates the observed UCRT64 heap corruption
# to the packaged liblto_plugin.dll rather than either linker.  Isolate the
# same unverified linker plugin path as target libraries, and expose native
# zlib/zstd outside the custom target sysroot.  A PE host has no rpath, so this
# bootstrap build path is not embedded in the installed tools.  Use a response
# file so libtool does not discard the GCC driver option while rewriting
# shared-library links.
BOOTSTRAP_HOST_LDFLAGS=$CUR/ldflagsm-bootstrap-host
MINGW_HOST_LIBDIR=$(cygpath -am "$MINGW_PREFIX/lib") || exit 255
cat > "$BOOTSTRAP_HOST_LDFLAGS" <<EOF || exit 255
-static-libstdc++
-fno-use-linker-plugin
-L$MINGW_HOST_LIBDIR
EOF
grep -Fxq -- '-static-libstdc++' "$BOOTSTRAP_HOST_LDFLAGS" || exit 255
if grep -Fxq -- '-static-libgcc' "$BOOTSTRAP_HOST_LDFLAGS"; then
exit 255
fi
grep -Fxq -- '-fno-use-linker-plugin' "$BOOTSTRAP_HOST_LDFLAGS" || exit 255
grep -Fxq -- "-L$MINGW_HOST_LIBDIR" "$BOOTSTRAP_HOST_LDFLAGS" || exit 255

echo current utc time 3 is $(date -u)

../configure --prefix=$CUR/out --target=x86_64-w64-mingw32 --with-sysroot=$CUR/out/x86_64-w64-mingw32 --with-build-sysroot=$(cygpath -am $CUR/out/x86_64-w64-mingw32) --enable-bootstrap --with-build-config=bootstrap-O3 --with-stage1-ldflags="@$BOOTSTRAP_HOST_LDFLAGS" --with-boot-ldflags="@$BOOTSTRAP_HOST_LDFLAGS" --enable-mingw-wildcard --enable-version-specific-runtime-libs --enable-checking=release --with-local-prefix=/local --with-native-system-header-dir=/include --with-arch=haswell --with-tune=skylake --with-gcc-major-version-only --enable-tls --disable-cet --disable-vtable-verify --enable-plugin --with-system-zlib --with-{gmp,mpfr,mpc,isl}=${MINGW_PREFIX} --enable-libatomic --enable-threads=posix --enable-graphite --enable-fully-dynamic-string --enable-libstdcxx-filesystem-ts --enable-libstdcxx-time --disable-libstdcxx-pch --enable-libstdcxx-backtrace=yes --with-libstdcxx-zoneinfo="yes" --enable-lto --enable-libgomp --disable-libssp --disable-libvtv --enable-shared=libgcc,libstdc++,libgomp,libatomic --disable-multiarch --disable-multilib --disable-rpath --disable-nls --disable-werror --disable-symvers --disable-libstdcxx-debug --disable-win32-registry --enable-languages=c,c++,lto --disable-sjlj-exceptions --with-specs-file="$CUR/mingw64.specs" || exit 255
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

# Bundle the complete recursive host DLL closure required by the installed
# compiler, linker, cc1 frontends, LTO tools, and shared target runtimes.
bash "$CUR/mingw64-runtime-dlls.sh" "$CUR/out" "$MINGW_PREFIX" || exit 255

echo current utc time 4 is $(date -u)
TME=$(date +%s)
TMT0=$((($TMM-$TMS)/60))
TMT1=$((($TME-$TMM)/60))
TMA=$(($TMT0+$TMT1))
echo "part 1 took $TMT0 min, part 2 took $TMT1 min, which sum to $TMA min together!"

cd $CUR

TOOLCHAIN_DIR=x86_64-w64-mingw32-msys2$SUF
mv out "$TOOLCHAIN_DIR" || exit 255
bash "$CUR/mingw64-smoke.sh" "$CUR/$TOOLCHAIN_DIR" || exit 255
tar -I 'bzip2 -9' -cf x86_64-w64-mingw32-cross_msys2$SUF.tb2 "$TOOLCHAIN_DIR" || exit 255

exit 0
