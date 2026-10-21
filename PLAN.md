# A macOS-first OpenJDK for Minecraft (working name: TBD; not "Cadence JDK")

Asked for on 2026-10-20: "make your own custom JDK using Zulu as the base ... optimize it specifically for macOS, with
fallbacks for Windows and Linux (theoretical, untestable here)". Started right after Cadence's night-5 passes.

## Base
- The installed Zulu is 25.0.2+10 (Zulu25.32+17-CA), built from upstream commit bcac72d140fc. Upstream source of the same
  release: github.com/openjdk/jdk25u, tag jdk-25.0.2+10. Zulu adds two Azul modules (com.azul.crs.client, Azul's
  runtime-telemetry client, and com.azul.tooling) that we neither need nor may brand. Research (research/BUILD.md, LEGAL.md)
  decides between the upstream tag and Azul's published source bundle.
- License: GPLv2 + Classpath Exception (not permissive): every binary we ship comes with its complete source; no "Java",
  "Zulu" or "Azul" in the name (research/LEGAL.md).

## Why a JDK at all (what a mod cannot change), from Cadence's measurements
1. G1 Remark pauses are ~98% class unloading ("G1 Complete Cleaning": 8-78 ms) although Minecraft almost never unloads a
   class loader. Cadence's GC policy made them rarer; making each one cheap needs HotSpot.
2. Young pauses are object copying by 8 GC workers on 4 P + 4 E cores (M2): workers on efficiency cores stretch pauses.
   HotSpot sets no thread QoS on macOS (to verify: research/APPLE.md).
3. JVM memory: symbols 26 MB, compiled-code metadata ~37 MB, G1 structures 60-80 MB, code cache ~100 MB.
4. Apple Silicon specifics: 128-byte cache lines, 16 KB pages, heterogeneous cores, W^X toggling for JIT code.

## Measurement
Cadence's harness runs the game with any Java: `JAVA=/path/to/bin/java tools/cadence-test.sh ...`. Every change is A/B'd
against stock 25.0.2+10 built the same way (not against Zulu, so the build itself isn't a variable): GC pauses (JFR),
benchmark scene, flight soak, footprint.

## Build constraints (this Mac)
M2 MacBook Air, 8 GB RAM, ~33 GB free, Command Line Tools only (no Xcode: no `metal` compiler for java.desktop's Java2D
shaders), GNU make 3.81, bash 3.2, no autoconf yet (Homebrew), boot JDK Zulu 25.

## Status (2026-10-21 ~00:15)
- [x] Research: research/BUILD.md, APPLE.md, LEGAL.md (three Haiku agents)
- [x] Name: working name **Vivace** (shortlist in LEGAL.md; the user picks; trademark search still needed)
- [x] Source: jdk25u jdk-25.0.2+10 (A/B baseline, src/) and jdk-25.0.5-ga (release, src-release/)
- [x] Builds without Xcode (stand-in metal tools + runtime shader compile); a full build takes ~5 min on the M2
- [x] Patch: UseThreadQoS (worst young pauses about -1/3)
- [x] Patch: G1ClassUnloadingInterval, manageable (Remark -39%; with Cadence scheduling, every in-play Remark 0.5-3.7 ms)
- [x] -mcpu=apple-m1 + link-time-opt: measured, no gain, not used
- [x] Release build + packaging (build-tools/build-release.sh), ad-hoc signing, game runtime, source archive
- [x] Run Minecraft on the release runtime end to end (production launch, 18 mods); Zulu A/B (in-play Remark -73%)
- [x] jtreg: G1 + class unloading suites: 77 passed, 0 failed
- [x] 34-minute stability soak: no crash, no growth
- [x] Windows/Linux: CROSS-PLATFORM.md (theoretical)

## Status (2026-10-21 day: optimization, testing, legal)
- [x] Research: research/OPTIMIZE.md (one Haiku agent): nothing flag-level left; the lever is the JDK version
- [x] Flag tests on 25 (UseSIMDForMemoryOps, isb spin-wait): no gain (CPU benchmark ABBA)
- [x] JDK 26 built (boot JDK), JDK 27.0.1 built; Minecraft 26.3 + Fabric + Cadence run on 27 unchanged
- [x] Plain 27 vs Vivace 25: same CPU. Patches ported to 27 (10 files, 151 lines)
- [x] Vivace 27 vs Vivace 25: smaller heap in 4-minute runs, but in 14-34-minute play JDK 26+'s heap sizing grows the
      heap and eden (193 vs 41-51 young pauses over 8 ms, ~200 MB more resident). Cause found (concurrent marking CPU
      counted as GC overhead); fix = young generation capped at 128 MB on Java 26+ (Cadence default): then 27 = 25.
      Vivace 25 stays recommended (LTS, no tuning needed)
- [x] Release script: either line, vendor/bug URLs, runtime release file, build scripts in the source archive, game runtime
      without the >32 GB-heap class-data archives; dist/vivace-27.0.1+9-vivace.1/
- [x] jtreg on Vivace 27 (gc/g1, class unloading, gc/arguments, dcmd/vm, runtime/Thread): 171 passed, 0 failed
- [x] Production launch (18 mods) on Vivace 27, directly and through Cadence's switch (Cadence beta.12)
- [x] 34-minute soak on Vivace 27: no crash, metaspace/code cache flat; heap committed grew to the 2 GB cap (above)
- [x] Legal pass: research/LEGAL2.md (model, checklist, user-only steps); Cadence's opt-in Java switch (Video Settings >
      Java), README/INSTALL licence and trademark wording
