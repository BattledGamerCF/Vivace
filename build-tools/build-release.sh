#!/bin/bash
# Builds the release from src-release (branch vivace-25.0.5 = jdk-25.0.5-ga + PATCHES.md) and packages dist/:
#   NAME-VERSION-macos-aarch64-jdk.tar.gz       the full JDK (the macOS bundle layout: NAME-VERSION.jdk/Contents/Home)
#   NAME-VERSION-macos-aarch64-runtime.tar.gz   a game runtime (jlink: the modules Minecraft + Fabric + mods use)
#   NAME-VERSION-src.tar.xz                     the complete corresponding source (GPLv2 section 3)
#   SHA256SUMS, README.md, PATCHES.md
# usage: build-tools/build-release.sh [--no-build]
# The name is a working name (research/LEGAL.md has the shortlist); change NAME/BUNDLE_ID here and rebuild.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src-release"
NAME=Vivace
NAME_LC=vivace
BUNDLE_ID=dev.vivace
REV=1                              # our release number on top of the OpenJDK update
BOOT=$(/usr/libexec/java_home -v 25)
CONF=release
cd "$SRC"
UPDATE=$(sed -n 's/^DEFAULT_VERSION_UPDATE=//p' make/conf/version-numbers.conf)
FEATURE=$(sed -n 's/^DEFAULT_VERSION_FEATURE=//p' make/conf/version-numbers.conf)
BUILD_NUM=$(git describe --tags --abbrev=0 2>/dev/null | sed -n 's/.*+\([0-9]*\).*/\1/p'); BUILD_NUM=${BUILD_NUM:-8}
VERSION="$FEATURE.0.$UPDATE+$BUILD_NUM-$NAME_LC.$REV"
echo "== $NAME $VERSION"
if [ "${1:-}" != "--no-build" ]; then
  T="$ROOT/build-tools"
  nice bash configure --with-conf-name=$CONF --with-boot-jdk="$BOOT" \
    --with-debug-level=release --with-native-debug-symbols=none --with-jvm-variants=server \
    --with-version-pre= --with-version-opt="$NAME_LC.$REV" --with-version-build="$BUILD_NUM" \
    --with-vendor-name="$NAME" --with-vendor-version-string="$NAME-$FEATURE.0.$UPDATE.$REV" \
    --with-macosx-bundle-name-base="$NAME" --with-macosx-bundle-id-base="$BUNDLE_ID" \
    --with-macosx-codesign=hardened --with-macosx-codesign-identity=- \
    ${EXTRA_CONFIGURE:-} \
    --with-jobs=4 --disable-warnings-as-errors METAL="$T/metal" METALLIB="$T/metallib" > "$ROOT/configure-$CONF.log" 2>&1
  nice make images CONF=$CONF > "$ROOT/build-$CONF.log" 2>&1 || { tail -30 "$ROOT/build-$CONF.log"; exit 1; }
fi
IMG="$SRC/build/$CONF/images"
DIST="$ROOT/dist"; rm -rf "${DIST:?}"; mkdir -p "$DIST"
"$IMG/jdk/bin/java" -version
# the full JDK, in the macOS bundle layout launchers and /Library/Java/JavaVirtualMachines expect
BUNDLE=$(ls -d "$IMG"/jdk-bundle/*.jdk | head -1)
( cd "$(dirname "$BUNDLE")" && tar -czf "$DIST/$NAME_LC-$VERSION-macos-aarch64-jdk.tar.gz" "$(basename "$BUNDLE")" )
# the game runtime: what Minecraft 26.x, Fabric and common mods need (jdeps over the game's classpath, plus the modules
# reached by reflection: zip file systems, TLS for sign-in, charsets, locales, JFR, management, attach for profilers)
MODS=java.se,jdk.unsupported,jdk.unsupported.desktop,jdk.zipfs,jdk.crypto.ec,jdk.crypto.cryptoki,jdk.charsets,jdk.localedata,jdk.management,jdk.management.jfr,jdk.jfr,jdk.httpserver,jdk.incubator.vector,jdk.net,jdk.naming.dns,jdk.attach,jdk.jcmd,jdk.jdwp.agent,jdk.nio.mapmode,jdk.sctp,jdk.security.auth,jdk.security.jgss,jdk.xml.dom,jdk.dynalink
RT="$DIST/$NAME-$VERSION-runtime.jdk/Contents/Home"
mkdir -p "$(dirname "$RT")"
"$IMG/jdk/bin/jlink" --module-path "$IMG/jdk/jmods" --add-modules "$MODS" --strip-debug --no-man-pages --no-header-files \
  --compress=zip-6 --generate-cds-archive --output "$RT"
cp "$BUNDLE/Contents/Info.plist" "$(dirname "$RT")/Info.plist"
codesign --verify --verbose=1 "$RT/bin/java" && codesign --verify "$RT/lib/server/libjvm.dylib"
( cd "$DIST" && tar -czf "$NAME_LC-$VERSION-macos-aarch64-runtime.tar.gz" "$NAME-$VERSION-runtime.jdk" && rm -rf "$NAME-$VERSION-runtime.jdk" )
# the complete corresponding source: this branch, as committed
git -C "$SRC" archive --format=tar --prefix="$NAME_LC-$VERSION-src/" HEAD | xz -T4 -6 > "$DIST/$NAME_LC-$VERSION-src.tar.xz"
cp "$ROOT/README.md" "$ROOT/PATCHES.md" "$ROOT/INSTALL.md" "$DIST/"
( cd "$DIST" && shasum -a 256 *.tar.* > SHA256SUMS )
ls -la "$DIST"
