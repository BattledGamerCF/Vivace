# Patches on top of OpenJDK 25 (jdk25u)

Each patch is one commit on the `vivace-25.0.5` branch of the OpenJDK checkout (src-release, from tag jdk-25.0.5-ga), with
a change notice in every file it touches (GPLv2 section 2(a)). Measured with Cadence's harness: Minecraft 26.3 + Cadence,
an M2 MacBook Air (4 P + 4 E cores, 8 GB), a 4-minute flight over new terrain (`gcsoak.sh`, -Xmx2048m) and the benchmark
turn (`gcab.sh`), interleaved A/B runs against the same source built without the patch (never against another vendor's
binary, so the build itself is not a variable).

## 1. Build without Xcode (Java2D shaders)
configure and make need Apple's `metal` and `metallib` for one file, Java2D's shaders.metal, and those ship only with full
Xcode. build-tools/metal and metallib stand in for them: the (include-inlined) Metal source is carried into
lib/shaders.metallib, and MTLGraphicsConfig.m / MTLPipelineStatesStorage.m compile it with the Metal API
(newLibraryWithSource) when the file is not a compiled library. All 34 shader functions compile that way. Java2D is only
used by desktop Java UI; Minecraft never touches it. Effect on games: none (lets this Mac build the JDK).

## 2. UseThreadQoS (macOS; default on)
HotSpot set no quality-of-service class on any thread (JDK-8267720 was closed Won't Fix), so on Apple Silicon a
stop-the-world GC pause could run on efficiency cores and last as long as its slowest worker. With G1 or Parallel GC: the
VM thread and the stop-the-world workers ("GC Thread#") start user-interactive, concurrent GC and housekeeping threads
utility; Java and JIT compiler threads keep the inherited class. Set at creation with pthread_attr_set_qos_class_np
(os_bsd.cpp). `-XX:-UseThreadQoS` turns it off.
- Flight soak x2 (A/B): total young pause time about the same (2,000 vs 1,946 ms; 2,205 vs 2,119 ms), worst young pause
  24 vs 38 ms and 51 vs 74 ms: the long tail shrinks by about a third. Remark unchanged.

## 3. G1ClassUnloadingInterval (default 4)
Minecraft's G1 Remark pauses are ~98% class unloading ("G1 Complete Cleaning", every class and compiled method checked:
8-100 ms on an M2) although the game almost never unloads a class loader. With this flag a marking cycle unloads classes
and code only every Nth cycle; cycles started because the code cache or metaspace needs room always unload, so neither
grows without bound (turning class unloading off entirely, -XX:-ClassUnloadingWithConcurrentMark, made the code cache grow
35 -> 100 MB in 4 minutes). Decided at the cycle's concurrent start (G1Policy::initiate_conc_mark), because it also decides
how that pause marks roots: the root closures and Remark read the same per-cycle value. 1 = upstream behaviour.
Manageable (-XX:G1ClassUnloadingInterval can be changed at run time through HotSpotDiagnosticMXBean).
- Flight soak x2 vs the QoS build (every cycle unloads): Remark time 236 vs 389 ms and 211 vs 345 ms (-39%), Remarks over
  8 ms 4 vs 9 and 5 vs 11. Cycles that keep classes end in a 0.5-1.4 ms Remark; the unloading ones carry the work of the
  skipped cycles (~27 ms on average, up to 104-127 ms during JIT warm-up). Code cache the same (bounded by the code-cache
  cycles, which always unload).
- With Cadence's GC policy scheduling the unloading cycles into menus (interval 12 during play, 1 for a cycle it starts
  while a menu is open), a flight with the pause menu opened every ~30 s: every unloading Remark (18, 57, 26, 9, 11 ms)
  happened in a menu; every Remark during play took 0.5-3.7 ms, G1's own safety-net cycles included. The same flight on
  stock G1 had 126 Remarks of 8-100 ms.

## Tried and not kept
- **-mcpu=apple-m1 + link-time-opt** (HotSpot and JDK C code built for Apple's cores, the JVM link-time optimized): flight
  soak x2 A/B against the same source built plainly: young pause time 2,009 / 1,827 vs 2,012 / 2,114 ms, Remark 144 / 158 vs
  170 / 165 ms, worst young pause 37 / 62 vs 20 / 28 ms: no difference beyond run-to-run noise. Not used (less to go wrong).
