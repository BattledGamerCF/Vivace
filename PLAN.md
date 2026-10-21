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
- [ ] -mcpu=apple-m1 + link-time-opt build (A/B running)
- [ ] Release build + packaging (build-tools/build-release.sh), ad-hoc signing, game runtime, source archive
- [ ] Run Minecraft on the release runtime end to end (Cadence harness), production launch
- [x] Windows/Linux: CROSS-PLATFORM.md (theoretical)
