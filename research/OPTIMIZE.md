# HotSpot optimization research for Vivace (Haiku agent, 2026-10-21; saved by the main session, condensed)

Tags: [verified] read in jdk25u jdk-25.0.5-ga source, JBS, a JEP or JDK 25 docs; [search] secondary; [estimate].

## Findings
1. **"Evacuation Failure: Pinned"**: the only pin source in HotSpot is JNI Get/ReleasePrimitiveArrayCritical
   (jni.cpp -> G1CollectedHeap::pin_object) [verified]. The JDK's own libzip glue (Inflater.c, Deflater.c) pins on every
   heap-array inflate/deflate [verified source] - a likely source in Minecraft (region files, jars). Pinned young regions are
   promoted, not copied: the cost is old-gen waste until a marking cycle, plus fix-up work [verified JEP 423]. Measured here:
   94 of 3,609 young pauses in a 34-min soak, same duration as the others. JDK-8377811 (optional evacuation could move pinned
   objects; fixed 25.0.3) is consistent with being in 25.0.5's source [verified].
2. **FFM**: Linker.Option.critical skips the thread-state transition, the full membar and the safepoint poll; heap access in
   critical calls does not pin (the thread stays in Java state; a long call delays safepoints instead) [verified
   downcallLinker_aarch64.cpp]. Savings ~4-10 ns per call [search, old hardware]. Cadence already links its per-draw calls
   critical. No JDK 26/27 downcall speed-ups found [search].
3. **G1 speed**: JEP 522 (JDK 26, second card table, 5-15% on reference-heavy apps) is not backportable (44 linked issues);
   JDK 24/25 remset changes are already in 25. Nothing in 24-26 targets survivor copy cost [verified Schatzl posts].
4. **JIT**: no evidence-backed flag wins for this workload; AArch64 sin/cos are fdlibm-port intrinsics [verified].
5. **Safepoints**: JDK 25 has a Safepoint Latency JFR event (JEP 518) [verified JBS comment].
6. **Memory**: G1 retention knobs for pinned regions (G1NumCollectionsKeepPinned 8, diagnostic) [verified g1_globals.hpp].
7. **W^X lazy switching** (JDK-8328306, JDK 27): ~40 files, SIGBUS healing, follow-up fixes: not backportable; no toggle-rate
   data anywhere [verified].
8. **Minecraft flag lore** (Aikar etc.): unbenchmarked; MaxTenuringThreshold=1 and young sizing 30/40 are worth an A/B only.
9. Upstream direction: rebasing on JDK 26/27 brings JEP 522, lazy W^X, COH default; much more than backports could.

## Agent's top candidates (main session's notes in brackets)
1. libzip without critical pins (copy via GetByteArrayRegion/SetByteArrayRegion) [measured pinned pauses are rare and not
   slower: low value; would add a memcpy per call].
2. Pin attribution hook (diagnostic). 3. JDK-8377811 present [source consistent]. 4-5. Cadence critical/batched downcalls
   [already critical]. 6. Young sizing / MaxTenuringThreshold=1 A/B. 7. Pinned-retention diagnostics. 8. Safepoint latency
   measurement. 9. W^X toggle counting. 10. Rebase on JDK 26/27 for JEP 522 [the real throughput lever; GPL patches port].
Sources: jdk25u jdk-25.0.5-ga (jni.cpp, collectedHeap.hpp, g1CollectedHeap.inline.hpp, g1YoungCollector.cpp, Inflater.c,
Deflater.c, downcallLinker_aarch64.cpp, LinkerOptions.java, CallingSequence.java, g1_globals.hpp, c2_globals*.hpp); JEPs 423,
475, 518, 522, 519; JBS JDK-8276094, 8377811, 8340827, 8328306, 8326012; tschatzl.github.io JDK 24/25/26 G1 posts; Aikar's
flags (docs.papermc.io); panama-dev threads (2020-2023).
