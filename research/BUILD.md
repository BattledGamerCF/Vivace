# Build and fork research (Haiku agent, 2026-10-20; saved by the main session)

Tags: [V] verified on the source page, [S] search snippet, [E] estimate. The agent could not write files; this is its report,
condensed, with the main session's corrections marked **Correction**.

## Base
- Azul publishes no Zulu source tree; sources are "upon request" for three years under GPLv2+CPE [V docs.azul.com/core/tpls].
  Zulu 25.0.2 = OpenJDK 25.0.2+10 (tag jdk-25.0.2+10, commit 405a5699e) [V]. Newer: Zulu 25.38 = OpenJDK **25.0.5+8**
  (tag jdk-25.0.5+8 / jdk-25.0.5-ga, 2026-10-20) [V github.com/openjdk/jdk25u/tags].
- Recommendation: fork openjdk/jdk25u and ship the newest GA tag (security fixes); keep 25.0.2+10 for A/B against the
  installed Zulu. Zulu's own additions (JavaFX builds, CRaC simulation on macOS, CRS agent) are not needed.

## Building on macOS
- configure requires `metal` and `metallib` (`--version` must succeed) [V make/autoconf/toolchain.m4]; the rule compiles
  java2d/metal/shaders.metal to shaders.air and links lib/shaders.metallib [V ClientLibraries.gmk]; no option to skip it.
  **Correction:** solved without Xcode in this project: build-tools/metal and metallib pass the (include-inlined) source
  through, and the two loaders (MTLGraphicsConfig.m, MTLPipelineStatesStorage.m) compile it with
  newLibraryWithSource at first use (all 34 shader functions compile through the Metal API). Configure and `make images`
  succeed with the Command Line Tools only (clang 17); a full build takes ~5 minutes on the M2 with JOBS=4.
- Tool minimums: autoconf 2.69+ (installed 2.73 via Homebrew), GNU make 3.81+ (4.0+ recommended), bash 3.2+ [V building.md].
  Boot JDK officially N-1; Zulu 25 as boot works (used here).
- Resources: 8 cores / 8 GB advisable; default JOBS = min(GB, cores) = 8 here, too many: use --with-jobs=4 [V].
  `--with-native-debug-symbols=none` saves a lot of disk. ccache: --enable-ccache.

## configure options
- --with-jvm-features list: cds compiler1 compiler2 dtrace epsilongc g1gc jfr jni-check jvmti link-time-opt management
  minimal opt-size parallelgc serialgc services shenandoahgc vm-structs zero zgc [V jvm-features.m4]; link-time-opt must be
  enabled explicitly; giving the option replaces the default set.
- No PGO support upstream [V/S]. No CPU flag set on macOS aarch64 by default; HotSpot takes --with-extra-cxxflags, JDK C
  code --with-extra-cflags [V flags-cflags.m4]. -mcpu=apple-m1: LLVM 13+ [S]; safe on M1-M5 is [E] (M1 is the baseline ISA).
- Branding [V jdk-version.m4]: --with-vendor-name/-url/-bug-url/-vm-bug-url, --with-vendor-version-string,
  --with-version-pre/-opt/-build, --with-macosx-bundle-name-base/-id-base/-build-version.
- Codesign [V jdk-options.m4]: --with-macosx-codesign=auto|hardened|debug; identity default "openjdk_codesign"; ad-hoc:
  `--with-macosx-codesign=hardened --with-macosx-codesign-identity=-` [E]. Entitlements from make/data/macosxsigning
  (allow-jit, allow-unsigned-executable-memory, disable-library-validation, allow-dyld-environment-variables, debugger).

## Deliverable
- images/jdk (exploded), images/jdk-bundle (macOS .jdk bundle); `make product-bundles` makes tar.gz [V Bundles.gmk].
- Gatekeeper: unsigned downloads need first-launch approval or `xattr -dr com.apple.quarantine`; Apple silicon accepts
  ad-hoc signatures [S]. Notarization needs a paid Developer ID.
- Minecraft 26.x uses Mojang's jlink runtime "java-runtime-epsilon" (Java 25) [V piston-meta]. Module list: measured in
  this project with jdeps over the real classpath: java.base, java.desktop, java.instrument, java.naming, java.net.http,
  java.rmi, java.scripting, java.sql, jdk.httpserver, jdk.incubator.vector, jdk.javadoc, jdk.jfr, jdk.management,
  jdk.unsupported (+ reflective: jdk.zipfs, jdk.crypto.ec, jdk.charsets, jdk.localedata, java.logging).

## Launchers
- Prism: runs the candidate with a helper jar, reads os.arch, java.version, java.vendor [V JavaChecker.cpp]. Modrinth App:
  per-profile Java path [S]. Official launcher: per-installation Java executable [S]. CurseForge: not documented [open].

## Testing
- `make test-tier1` needs jtreg (--with-jtreg / JT_HOME) [V testing.md]; single tests: `make test TEST="jtreg:..."`.

## Windows and Linux (untestable here)
- Windows: Visual Studio 2019 16.8 to 2026 (CI: VS 2022), Cygwin or MSYS2 (CI: MSYS2), GNU make 4.0+ [V]. Linux: gcc 10+
  (14.2 known good) or clang 13+, X11/ALSA/fontconfig/CUPS headers; CI on ubuntu-24.04 [V]. No cross build from macOS to
  Windows [E]. Plan: GitHub Actions reusing jdk25u's build-linux/build-windows workflows.

## Existing patched OpenJDKs
- JetBrains Runtime: OpenJDK fork, branches jbr25 etc., GPLv2+CPE, macOS HiDPI/input/accessibility fixes [V github].

## Sources
building.md, testing.md (jdk25u); toolchain.m4, ClientLibraries.gmk, jvm-features.m4, jdk-version.m4, jdk-options.m4,
flags-cflags.m4, build-performance.m4, Bundles.gmk (openjdk/jdk); jdk25u .github/workflows; docs.azul.com release notes and
TPLs; Mojang piston-meta; PrismLauncher JavaChecker.cpp; JetBrains/JetBrainsRuntime.
