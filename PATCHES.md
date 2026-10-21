# Patches on top of OpenJDK 25 (jdk25u) and 27 (jdk27u)

Two lines, the same patches:
- **Vivace 27** (`vivace-27.0.1` branch of src27, from tag jdk-27.0.1-ga, built with a JDK 26 built from jdk26u
  jdk-26.0.2.1-ga): patches 1-3 below, ported (section "Vivace 27"); 4 is upstream's default there.
- **Vivace 25** (`vivace-25.0.5` branch of src-release, from tag jdk-25.0.5-ga): patches 1-4.

Each patch is one commit, with a change notice in every file it touches (GPLv2 section 2(a)). Measured with Cadence's harness: Minecraft 26.3 + Cadence,
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
- **MaxTenuringThreshold=3** (promote new terrain data after 3 young collections instead of up to 15, so it is copied
  fewer times): retried on Vivace, where extra marking cycles are cheap; ABBA flight soaks with menus: young pause time
  1,420 / 1,590 vs 1,574 / 1,467 ms: no difference.
- **-mcpu=apple-m1 + link-time-opt** (HotSpot and JDK C code built for Apple's cores, the JVM link-time optimized): flight
  soak x2 A/B against the same source built plainly: young pause time 2,009 / 1,827 vs 2,012 / 2,114 ms, Remark 144 / 158 vs
  170 / 165 ms, worst young pause 37 / 62 vs 20 / 28 ms: no difference beyond run-to-run noise. Not used (less to go wrong).

## Release vs Zulu 25.0.2 (what players use today), Cadence beta.10, flight with the pause menu every ~30 s
Remarks split by where they happened (pause-menu windows from the self-test log):

| during play | Zulu | Vivace 25.0.5+8-vivace.1 |
|---|---|---|
| Remark time | 194 / 251 ms | **52 / 67 ms** (-73%) |
| Remarks over 8 ms | 7 / 9 | **3 / 3** |
| longest Remark | 64 / 87 ms | **22 / 23 ms** |

The long Remarks moved into the menu (up to 180 ms there, unseen). Young pauses and heap size: the same once the Mac's heat
is accounted for: whichever runs second in a pair (hotter, fanless Air) shows more young-pause time and a bigger heap (G1
grows the heap when GC takes a larger share of time): Vivace first 771 MB, Zulu second 1,001 MB; Zulu first 779 MB, Vivace
second 1,229 MB. Flag defaults differ only in Azul's own CRS switches and the 25.0.5 Shenandoah changes.

## 4. UseCompactObjectHeaders on by default
JEP 519 (product in JDK 25) shrinks object headers from 12-16 to 8 bytes; upstream leaves it off. On by default here
(the arguments code already turns on the object monitor table it needs when neither flag is given; a user's
-XX:-UseCompressedClassPointers turns it back off with a warning). Cadence's Java defaults already set it, so with Cadence
nothing changes; for other games it saves heap (Cadence measured ~23 MB of Minecraft's heap on 10-12; JEP 519: up to 22%
less heap on SPECjbb).

## Vivace 27: the same patches on JDK 27.0.1
Why rebase: flag-level tuning of 25 found nothing more (UseSIMDForMemoryOps, an isb spin-wait, MaxTenuringThreshold,
ParallelGCThreads, AOT cache: all no gain), and the bigger G1 changes since 25 (JEP 522's second card table in 26, lazy
W^X switching and G1 heap sizing by GC time in 26/27) are too large to backport. Minecraft 26.3 (Java 25 class files),
Fabric and Cadence run on 27 unchanged.
- Port: patch 1 (Java2D loader) applied as is. Patch 2 (UseThreadQoS): the flag is declared in both of 27's
  RUNTIME_OS_FLAGS variants (Apple Silicon and Intel). Patch 3: JDK 27 has no G1Policy::initiate_conc_mark; the
  per-cycle decision moved into G1Policy::decide_on_class_unloading, called from decide_on_concurrent_start_pause when it
  chose a concurrent start (both of its paths); root closures and Remark read it as before. 10 files, 151 lines.
- JDK 27 deprecates -XX:InitiatingHeapOccupancyPercent in favour of -XX:G1IHOP (same meaning; the old name still works
  with a warning at every start). Cadence passes G1IHOP to Java 27+.
- Plain JDK 27 vs Vivace 25, crowded scene, ABBA: fps 1,053 / 1,099 vs 1,052 / 1,084; render CPU 0.49 / 0.47 vs 0.51 /
  0.49 ms a frame; server tick 4.03 / 3.90 vs 3.73 / 3.91 ms. No CPU difference beyond noise.
- **Vivace 27 vs Vivace 25**, flight over new terrain with the pause menu every ~30 s (gcmenu, -Xmx1280m), ABBA:

| | Vivace 25 | Vivace 27 |
|---|---|---|
| young pauses | 190 / 192, 1,253 / 1,005 ms | 383 / 291, 1,273 / 1,105 ms |
| young pauses over 8 ms | 50 / 31 | **20 / 23** |
| longest young pause | 69.9 / 19.6 ms | 20.5 / 18.8 ms |
| heap committed, peak | 1,024 / 1,016 MB | **750 / 786 MB** |
| Remark in play (total, longest) | 54 ms, 26.7 / 28 ms, 13.6 | 51 ms, 22.1 / 65 ms, 27.5 |
| code cache filled during the run | 27 / 24 MB | 34 / 26 MB |

  **Over 4 minutes only.** JDK 27's G1 starts with a smaller heap; the longer runs below show it doesn't stay that way.

### Longer play: 27's heap sizing works against a game (14-minute soaks, same route, -Xmx2048m)
JDK 26 changed G1's heap sizing: after every young collection it compares "GC CPU usage" with GCTimeRatio (4%) and
expands or shrinks the heap, and that usage now includes the CPU time of the concurrent GC threads (marking,
refinement) divided by the core count. A marking cycle's CPU time is charged to the next one or two short intervals,
so each cycle Cadence's GC policy starts (one every ~25 s) shows up as a 20-70% spike; four spikes and G1 expands the heap
by hundreds of MB at once (log: 679 -> 1,227 MB in one step). G1 then fills the bigger heap with eden (its pause goal is
200 ms), and young pause length follows eden size. Same Mac, same hour, 14-minute flights with menus:

| run | heap committed (end) | game RSS avg / max | eden avg | young pauses | over 8 ms | longest |
|---|---|---|---|---|---|---|
| Vivace 25 (x2) | 1,126 MB (mostly 630-760) | 940 / 1,117 MB | 90-110 MB | 1,574 / 1,751 | **41 / 51** | 17 / 20 ms |
| Vivace 27 | 1,741 MB | 1,136 / 1,495 MB | 535 MB | 298 | 193 | 35 ms |
| Vivace 27, GCTimeRatio=12 | 1,638 MB | 1,151 / 1,503 MB | | 286 | 169 | 33 ms |
| Vivace 27 + G1HeapSizingUsesConcurrentCPU off (x2) | 1,536 MB | 1,085 / 1,351 MB | 294 MB | 535 / 417 | 138 / 196 | 43 / 26 ms |
| the same + MaxGCPauseMillis=10 | 952 MB (stable 900-1,024) | | 289 MB | 539 | 112 | 26 ms |
| Vivace 25 + MaxGCPauseMillis=10 | 1,126 MB | | | 1,890 | 77 | 21 ms |
| **Vivace 27 + MaxNewSize=128m** (Cadence's default on Java 26+) | 693-1,126 MB | 866 / 1,001 MB | | 1,435 | 58 | 21 ms |
| Vivace 27 + the heap-sizing patch + MaxNewSize=128m | 621-712 MB | 883 / 1,009 MB | 82 MB | 1,725 | 41 | 18 ms |
| Vivace 25 + MaxNewSize=128m | 621-694 MB | 833 / 978 MB | | 2,030 | 79 | 60 ms |

Per 100 MB of eden JDK 27's young pauses are cheaper (1.7-1.9 ms vs 2.2-2.6 ms on 25: the JDK 26/27 G1 work does
pay off); 25 wins because its tighter heap keeps eden near 100 MB, so its pauses stay at 2-3 ms. The 34-minute soak on
Vivace 27 reached the 2,048 MB cap after 25 minutes (Vivace 25's soak: 650-1,126 MB).

**Outcome.** Capping the young generation (`-XX:MaxNewSize=128m`) brings Java 27 back to what Java 25 does on its own:
eden ~80 MB, 2.4 ms young pauses, the same resident memory. Cadence now passes it on Java 26 and newer (any vendor's:
stock JDK 26/27 have the same heap sizing), and not on 25, where it only adds collections. With it, Vivace 27 matches
Vivace 25 but does not beat it: the cheaper JDK 27 young collections don't show at an 80 MB eden, and the rest is
within run-to-run noise on a fanless Mac that heats up over a day of runs. **Vivace 25 stays the recommended build**: it
is the long-term-support line (JDK 27 is a six-month release), and it needs no tuning. Vivace 27 is built, tested and
packaged (dist/vivace-27.0.1+9-vivace.1) for whoever wants the newer JDK.
- Not kept: **G1HeapSizingUsesConcurrentCPU** (a flag making 27's heap sizing count pause time only, as 25 did; off by
  default with UseThreadQoS; branch exp-compiler-qos): alone it slowed the heap growth but kept long eden pauses (138 /
  196 over 8 ms); on top of the young-generation cap it left resident memory the same. GCTimeRatio=12 and
  MaxGCPauseMillis=10: no fix (above).
- Not kept: **UseUtilityQoSForCompilers** (JIT compiler threads on utility QoS, i.e. efficiency cores, so compilation
  leaves the performance cores to the game): crowded-scene ABBA, fps 931 / 906 off vs 978 / 913 on, render CPU 0.52 / 0.51
  vs 0.49 / 0.52 ms, tick time within 0.3 ms: no difference beyond noise.

## Stability
- **Vivace 27**: jtreg (8.2.1+1, test natives built with `make test-image-hotspot-jtreg-native`) on gc/g1, gc/class_unloading,
  runtime/ClassUnload, gc/arguments, serviceability/dcmd/vm, runtime/Thread, gc/TestSystemGC: **171 passed, 0 failed**; 4
  skipped by the tests themselves (no large pages on macOS, 8 GB is too little RAM for two of them), 15 not run (they
  need a debug build or Linux: NUMA, glibc malloc). Production launch (the release jar + 17 other mods: Essential,
  Lithium, JEI, Xaero's Minimap, Jade, ImmediatelyFast, Continuity, Dynamic FPS, EntityCulling, Mod Menu, ...): a flight,
  menus, Video Settings, the benchmark and leaving the world, on Vivace 27 directly and through Cadence's Java switch
  (launched on Zulu 25, restarted itself onto Vivace 27): the same log errors as on Vivace 25 (offline-account
  sign-in messages, AppleSkin's Mod Menu hook without cloth-config), nothing from Java 27.
- jtreg on the release build (G1ClassUnloadingInterval 4, compact headers on): test/hotspot/jtreg/gc/g1 61 passed, 14 not run
  (need debug-build options, WhiteBox or Linux NUMA), gc/class_unloading 5/5, runtime/ClassUnload 11/11. 0 failures.
- 34-minute soak on the release runtime with Cadence: flight over new terrain, pause menu every ~70 s: no crash; metaspace
  flat (165-166 MB); code cache steady (profiled heap ~100 MB unallocated throughout; non-profiled -5 MB in 30 min); heap
  after GC 513-724 MB, no trend. In play: 179 Remarks, 253 ms in all, 8 over 8 ms, longest 29.7 ms (Zulu spends 200-250 ms
  of Remark in 4 minutes of the same flight). Unloading Remarks in menus: up to 65 ms.
- **ParallelGCThreads=4** (one stop-the-world worker per performance core, with QoS): ABBA flight soaks: young pause time
  1,703 / 1,953 ms (4 workers) vs 1,699 / 1,570 ms (8); over 8 ms 33 / 51 vs 30 / 23. The default 8 stays.
- **AOT cache (JEP 514/515, a JDK 25 feature, not a patch)** for Minecraft + Fabric in the production setup: training run
  wrote 261 MB (908 classes skipped: everything Fabric's Knot loader loads, i.e. the game and mods); launch to in-world
  7-8 s without, 6-7 s with (1-s resolution, 3 each). The first JVM, before Cadence's Java-defaults restart, can't use a
  cache made with compact headers on. Not worth 261 MB; not used.
