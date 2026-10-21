# HotSpot / Apple Silicon research for a Minecraft-tuned OpenJDK 25

Scope: the three question groups A (HotSpot on macOS/AArch64), B (Metal, Objective-C and Swift from Java) and C (Apple hardware facts). Target base: JDK 25 GA line.

## Method and confidence

- Sources were read with WebFetch (github.com/openjdk/jdk raw files, JBS bug pages, JEPs, mail archives, Wikipedia, Apple pages) and WebSearch. Nothing was cloned, downloaded or run.
- WebFetch returns a summary of each page, not raw text. Quotes below are close to the source but not guaranteed verbatim, and line numbers were not available. Items marked [verified] were read directly from the page text; items marked [search] came from search snippets or secondary sources; items marked [estimate] are my inference.
- Several JBS pages came back with partial data (no comments, no reviewers). Those gaps are listed in Open questions.
- Apple's developer.apple.com pages for Porting JITs, ProcessInfo.ThermalState and the Game Mode docs returned no body text. Apple claims below are from the archived QoS guide and from third-party sources only.
- Corrections to the brief: (1) HotSpot does not read hw.perflevel* anywhere on macOS; it counts all cores. (2) JDK-8317809 is real but is an unrelated code-cache fix (JDK 22). JDK-8333348 could not be read (JBS returned a login page). (3) JEP 544 (AOT code) is integrated in JDK 28, not 25. (4) JEP 516 (AOT object caching with any GC) is JDK 26. (5) The lazy W^X fix JDK-8328306 is fixed in JDK 27, not in 25. (6) Nmethod relocation (JDK-8316694) is JDK 26; hot-code grouping (JDK-8326205) is JDK 27. (7) Java2D Metal became the default in JDK 19, not in 17.

---

## A1. Thread QoS, P/E cores, GC and JIT thread counts

**No QoS anywhere in HotSpot.** [verified] Reading os_bsd.cpp (https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/os/bsd/os_bsd.cpp), os_posix.cpp (https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/os/posix/os_posix.cpp) and os_bsd_aarch64.cpp (https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/os_cpu/bsd_aarch64/os_bsd_aarch64.cpp) found no pthread_set_qos_class_self_np, no QOS_CLASS_* and no pthread_attr_set_qos_class_np. So the VM thread, GC workers, concurrent GC threads and compiler threads all get the default QoS that the creating thread gives them. The creation path is not in os_bsd.cpp: the os_posix.cpp comment points to os_linux.cpp for os::create_thread, and the set of thread attributes is read-only there.

**Java thread priorities are a no-op on macOS by default.** [verified] os_bsd.cpp: `os::set_native_priority` returns early when `ThreadPriorityPolicy == 0` (the default, per the file's comment). With policy 1 it calls pthread_setschedparam (not setpriority, which is compiled out on macOS). os_bsd.cpp maps Java priorities 1–11 to Mach values 27–36 (Norm = 31).

**Only QoS-related JBS items found:**
- JDK-8267720, "Investigate ARM asymmetric core architecture impact on the VM" (Gerard Ziemski, created 2021-05-25). Proposed using macOS QoS for VM threads. Resolution: Won't Fix, resolved 2023-01-06. Reason not stated. [verified] https://bugs.openjdk.org/browse/JDK-8267720
- JDK-8273121, "Investigate impact of big.little/hybrid archs on gc thread sizing" (Thomas Schatzl, 2021-08-30). Open, P4. Written about Intel Alder Lake hybrid cores; it does not mention Apple. [verified] https://bugs.openjdk.org/browse/JDK-8273121
- No JBS issue found reporting GC pauses lengthened by GC workers on Apple E-cores. [search, negative]

**Apple QoS facts.** [verified, archived Apple guide] https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/PrioritizeWorkWithQoS.html
- Primary classes in priority order: user-interactive, user-initiated, utility, background. Default sits between user-initiated and utility and is not meant for developers to choose. Unspecified means "infer".
- A pthread can take a QoS at creation (pthread_attr_set_qos_class_np) or change it itself later (pthread_set_qos_class_self_np). The guide does not say whether new threads inherit the creator's QoS. [search] the qos.h summary says new threads default to Default.
- Core placement (not in Apple's guide): [search, third-party] https://eclecticlight.co/2024/12/17/tune-for-performance-core-types/ says background QoS (9 or lower) runs only on E cores, higher QoS prefers P cores when one is free, and Game Mode gives game-category apps priority on E cores. Single-app measurements only; not Apple documentation.
- The main thread of a GUI app runs at user-interactive, per the archived guide. The java launcher starts the JVM main thread on a new thread, so inheritance there is unknown (open question).

**Processor counting and GC/JIT ergonomics.**
- os::Bsd::initialize_system_info reads `HW_NCPU` (hw.ncpu) and calls set_processor_count with a fallback of 1. [verified] No hw.perflevel, hw.physicalcpu or hw.activecpu reads in os_bsd.cpp.
- os::active_processor_count returns `ActiveProcessorCount` when it is set and positive; otherwise it returns the cached count. [verified] os_bsd.cpp (same file). So `-XX:ActiveProcessorCount=N` is honoured on macOS, and it also changes Runtime.availableProcessors().
- os::initial_active_processor_count (set in os::init_before_ergo) is the value the GC ergonomics use. [verified] https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/share/runtime/os.cpp
- ParallelGCThreads (default 0 = ergonomic): if N <= 8, threads = N; otherwise threads = 8 + (N-8) * num / den, with the 5/8 ratio from calc_parallel_worker_threads(5, den, 8) and den from VM_Version::parallel_worker_threads_denominator(). [verified formula] https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/share/gc/shared/workerPolicy.cpp . Resulting values [estimate, den assumed 8]: 8 cores -> 8, 10 -> 9, 12 -> 10, 14 -> 11, 16 -> 13.
- ConcGCThreads defaults to 0 (ergonomic). [verified] gc_globals.hpp. The G1 derivation from ParallelGCThreads was not read; I believe it is ParallelGCThreads/4 [estimate].
- CICompilerCount (CICompilerCountPerCPU on by default when neither flag is set): log_cpu = log2i(N); loglog = log2i(max(log_cpu,1)); count = max(log_cpu * loglog * 3/2, min_count); C1 = max(count/3, 1); C2 = count - C1. [verified formula] https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/share/compiler/compilationPolicy.cpp . Arithmetic [estimate, log2i assumed to be floor]: 8, 10, 12, 14 cores -> 4 compiler threads (1 C1, 3 C2); 16 cores -> 12 (4 C1, 8 C2). So a base M1 gets only four compile threads, all counted from hw.ncpu.
- Consequence: all of ParallelGCThreads, ConcGCThreads and CICompilerCount count E-cores as full workers, because HotSpot does not distinguish core types on macOS.

**Answer to the core-count question:** HotSpot uses hw.ncpu (all cores). It never asks for perflevel counts. Changing this would be a new os_bsd.cpp path (read hw.perflevel0.logicalcpu and hw.perflevel1.logicalcpu) plus a flag. JDK-8273121 suggests the GC sizing question has been open since 2021 for hybrid CPUs.

---

## A2. W^X on Apple Silicon (MAP_JIT, pthread_jit_write_protect_np)

**Mechanism.** [verified] os_bsd_aarch64.cpp (https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/os_cpu/bsd_aarch64/os_bsd_aarch64.cpp):
- `os::current_thread_enable_wx(WXMode mode)` computes `exec_enabled = mode != WXWrite` and, only when the state changes (or in non-product builds when the default is WXWrite), calls `pthread_jit_write_protect_np(exec_enabled)`. The state is tracked in a thread-local `_jit_exec_enabled`.
- `Thread::wx_enable_write()` handles the WXArmedForWrite state. The SIGBUS healing path in `PosixSignals::pd_hotspot_signal_handler` (MACOS_AARCH64 only) lets a write into the code cache, caught by SIGBUS, switch to WXWrite.
- `ThreadWXEnable __wx(mode, thread)` RAII objects are placed at call sites under `MACOS_AARCH64_ONLY`. JDK-8307817 names `interfaceSupport.inline.hpp` as the place where the most expensive ones live.
- `anon_mmap` adds MAP_JIT for exec mappings on macOS. `os::pd_commit_memory` uses mprotect for exec and does not replace MAP_JIT mappings (JDK-8234930).
- Default: write enabled, execute enabled only when needed. [verified via JDK-8328306 description] https://bugs.openjdk.org/browse/JDK-8328306

**Cost.** [verified, JBS claims, no benchmark attached] JDK-8359463 (Andrew Haley, created 2025-06-13, still Open) says "W^X adds a substantial overhead, up to 50ns in some cases, even on a fast CPU" and estimates that switching only when needed removes about 90% of switches. https://bugs.openjdk.org/browse/JDK-8359463

**Evidence of cost.** [verified] JDK-8302736 (fixed in 21 b25): Math.log on an M1 Max took 6200 ms with the dlog intrinsic and 860 ms with -XX:DisableIntrinsic=_dlog. The cause was the WXWrite lock placed inside the intrinsic path. https://bugs.openjdk.org/browse/JDK-8302736

**Lazy-switch history.**
- JDK-8330171 "Lazy W^X switch implementation" (Sergey Nazarkin): Won't Fix, resolved 2024-07-24. The author reported no performance degradation. The stated reason for rejection is not on the page. [verified]
- JDK-8307817 "make macOS W^X locking more fine grained" (Tobias Holenstein): duplicate of JDK-8328306.
- JDK-8328306 "AArch64: MacOS lazy JIT 'write xor execute' switching" (Gerard Ziemski; assignee Andrew Haley): Resolved, Fixed in JDK 27 (b09), resolved 2026-02-06. It flips the default to execute-enabled and switches to write only when needed. It lists three causes that were resolved separately: JDK-8377413 (guarantee on StressWXHealing), JDK-8377425 (TestWXHealing fails on macosx-aarch64 product), JDK-8377948 (PerfTraceTime not safe during VM shutdown). A backport to 25 would need those. [verified] https://bugs.openjdk.org/browse/JDK-8328306
- JDK-8263492 "Consider moving W^X state to JavaThread": Closed. JDK-8327860 (macOS 14.4 processes killed without hs_err): Closed, P1, linked to the W^X work. [verified via linked lists]

**Flags.** ThreadWXEnable, DefaultWXWriteMode and the UseOldWX switch are real, but I could not read the flag declarations (the globals file for bsd_aarch64 does not define them and the threadWXSetters path returned 404). AssertWXAtThreadSync defaults to true since JDK-8329748 (debug/diagnostic only). [search]

---

## A3. Cache line size, padding and false sharing

- **Compile-time default on aarch64:** DEFAULT_CACHE_LINE_SIZE = 64; DEFAULT_PADDING_SIZE = 2 * DEFAULT_CACHE_LINE_SIZE = 128. [verified] https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/cpu/aarch64/globalDefinitions_aarch64.hpp . Origin: JDK-8237842 (separate cache-line and padding constants), and JDK-8321269 made every platform define DEFAULT_CACHE_LINE_SIZE [search].
- **Runtime value on macOS:** VM_Version reads the D-cache line via `sysctl` with the numeric MIB `{CTL_HW, HW_CACHELINE}`, falling back to 16 bytes. It does not use the string name hw.cachelinesize, and it does not read CTR_EL0 for this. [verified] https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/os_cpu/bsd_aarch64/vm_version_bsd_aarch64.cpp . Apple reports hw.cachelinesize = 128 on M-series [search, cpufun blog: https://cpufun.substack.com/p/more-m1-fun-hardware-information ].
- **Consequence:** dcache_line_size() = 128 on macOS, so the vm_version_aarch64 defaults become AllocatePrefetchDistance = min(512, 3*128) = 384, AllocatePrefetchStepSize = 128, PrefetchScan/CopyIntervalInBytes and SoftwarePrefetchHintDistance = 384 [verified formulas; arithmetic estimate]. ContendedPaddingWidth stays at 128 (no raise is needed since 128 is not larger than the line). [verified logic, https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/cpu/aarch64/vm_version_aarch64.cpp ]
- **Hardware truth is disputed.** One computerenhance.com commenter says M-series L1D lines are 64 bytes and the 128-byte value applies to L2 only [search, unverified]. I found no microbenchmark. Treat 128 as "the OS-reported coherence/prefetch granule" and do not rely on it as the L1 line.
- **False sharing:** no Apple-specific JBS issue found. JDK-8321481 (reconsider default padding on x86_64) is open. [search]

---

## A4. Page size and large pages

- Native arm64 macOS uses 16 KB pages; Rosetta processes use 4 KB. [search: Ruby bug tracker and Linux-kernel and Asahi discussions] Apple's hw.pagesize = 16384 [search, cpufun].
- HotSpot uses os::vm_page_size() in its alignment helpers. [verified, os_bsd.cpp]
- **Large pages are not supported on macOS in HotSpot.** [verified] os_bsd.cpp: `os::large_page_init` has an empty body, and `os::can_commit_large_page_memory` says "we do not support huge pages." So -XX:+UseLargePages is a no-op here.
- G1 region, card-table and commit alignment: JDK-8155100 (AArch64 relax byte_map_base alignment) and JDK-8216989 (card dirtying out of bounds) are the relevant prior AArch64 issues. I found no JBS issue specific to 16 KB pages. [search]

---

## A5. Memory return (commit and uncommit on macOS)

- [verified via os_bsd.cpp summary] os::pd_uncommit_memory on macOS:
  - exec (code cache): `madvise(addr, size, MADV_FREE)` then mprotect(PROT_NONE). MADV_FREE leaves pages resident until the kernel needs them, so phys_footprint may not drop immediately [estimate].
  - non-exec (Java heap): `mmap(addr, size, PROT_NONE, MAP_PRIVATE|MAP_FIXED|MAP_NORESERVE|MAP_ANONYMOUS)`. The remap replaces the pages and releases them at once.
- os::pd_disclaim_memory uses `MADV_DONTNEED` on all platforms. [verified]
- MADV_FREE_REUSABLE is not used anywhere in HotSpot. [verified, no hits in the reads]
- Related JBS: JDK-7129726 (MADV_FREE before munmap; Won't Fix, old), JDK-8196820 (return unused heap via MADV_FREE/DONTNEED; resolution not read). [search]
- phys_footprint: no JBS issue found about macOS footprint accounting. Third-party reports say RSS includes resident clean pages and footprint excludes them, and footprint also counts compressed pages [search: JavaCPP issue 468, Rust crate docs].

---

## A6. CPU features and tuning knobs

**What VM_Version_bsd sets.** [verified] https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/os_cpu/bsd_aarch64/vm_version_bsd_aarch64.cpp
- Vendor `CPU_APPLE` is set unconditionally. Model comes from `hw.cpufamily`.
- Set unconditionally: FP, ASIMD, AES, PMULL, SHA1, SHA2.
- Set when present (sysctl): CRC32 (hw.optional.armv8_crc32), LSE (hw.optional.arm.FEAT_LSE or hw.optional.armv8_1_atomics), SHA512, SHA3, SB (hw.optional.arm.FEAT_SB).
- Not set: CPU_DIT, SVE (no SVE sysctl or support).
- Cache line: from sysctl (see A3). I-cache line fixed at 16 bytes. ZVA length from DCZID_EL0 (if BS field enabled).

**aarch64 defaults in vm_version_aarch64.cpp** [verified] https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/cpu/aarch64/vm_version_aarch64.cpp
- Apple is listed only for the SHA3 intrinsic: UseSIMDForSHA3Intrinsic defaults true on CPU_APPLE and CPU_QUALCOMM (when SHA3 is present).
- Apple is not in the vendor tables for UseSIMDForMemoryOps, AvoidUnalignedAccesses, OnSpinWaitInst or any prefetch tuning. So they stay at the global defaults below.
- UseBlockZeroing defaults true, but is disabled if is_zva_enabled() is false. BlockZeroingLowLimit = 4 * zva_length(). Apple's DCZID_EL0 value is unknown to me (open question).

**Global aarch64 defaults** [verified] https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/cpu/aarch64/globals_aarch64.hpp
- UseSIMDForMemoryOps = false (product). UseSIMDForArrayEquals = true. UseSIMDForBigIntegerShiftIntrinsics = true.
- AvoidUnalignedAccesses = false. UseBlockZeroing = true; BlockZeroingLowLimit = 256.
- SoftwarePrefetchHintDistance = -1 (off).
- UseLSE = false in the global definition, but vm_version sets it when the CPU has LSE [estimate: Apple M-series have LSE, so it is on].
- OnSpinWaitInst = "yield" (diagnostic). OnSpinWaitInstCount = 1, OnSpinWaitDelay = 40 ns.
- CodeEntryAlignment = 64, OptoLoopAlignment = 16, CodeCacheSegmentSize = 64.
- UseCRC32 = false by default; whether vm_version turns it on for Apple was not read [open].

**Experiment candidates (not JDK changes):** -XX:+UseSIMDForMemoryOps, -XX:OnSpinWaitInst=isb or sb (sb is only valid if FEAT_SB is set), and -XX:+UseCRC32 for Apple. Each needs a benchmark.

---

## A7. G1 class unloading in Remark

**Where the pause work is.** [verified, JDK 25 tag] https://github.com/openjdk/jdk/blob/jdk-25+36/src/hotspot/share/gc/g1/g1CollectedHeap.cpp
- `G1CollectedHeap::unload_classes_and_code` opens a CodeCache unlinking scope, calls `SystemDictionary::do_unloading`, then `complete_cleaning(class_unloading_occurred)` and the purge steps.
- The GCTraceTime labels in that function are: "G1 Complete Cleaning", "Purge Unlinked NMethods", "Unregister NMethods", "Free Code Blobs", "Purge Class Loader Data".
- `G1CollectedHeap::complete_cleaning` builds a `G1ParallelCleaningTask` and runs it on `workers()->active_workers()`. So the cleaning is parallel across GC workers, and the cost scales with the number of active workers and with the unloaded set.
- The purge work calls `ClassLoaderDataGraph::purge(true)` at the safepoint.

**History of the cost.**
- JDK-8048248 (origin, fixed in 9 b24, backed out and re-pushed as JDK-8049421): G1 class unloading after concurrent mark. Its flag JDK-8048269 ("Add flag to turn off class unloading after G1 concurrent mark") is the one to use for experiments [verified title; default not read]. https://bugs.openjdk.org/browse/JDK-8048248
- JEP 156 (G1: reduce need for full GCs) is Closed/Delivered in 8u40 [search]. Before it, G1 unloaded classes only in full GCs.
- JDK-8027543 "Turn off symbol table scan if not class unloading in G1 remark phase" (Thomas Schatzl, 2013): symbol table scan was "roughly 50%" of remark pause time in some applications. Closed as "Other" in 2020. [verified] https://bugs.openjdk.org/browse/JDK-8027543
- JDK-8290025 "Remove the Sweeper" (Erik Österlund; fixed in 20 b13): the sweeper is gone, so G1, Serial and Parallel unload code blobs inside the pause. [verified] https://bugs.openjdk.org/browse/JDK-8290025
- JDK-8317809 "Insertion of free code blobs into code cache can be very slow during class unloading" (Thomas Schatzl; fixed in 22 b27): free-list insertion was O(n), causing pauses of seconds in a stress test. Fixed in JDK 22, so it is in JDK 25. [verified] https://bugs.openjdk.org/browse/JDK-8317809
- JDK-8322630 "Remove ICStubs and related safepoints" (Erik Österlund; fixed in 23 b10). Thomas Schatzl's measurements on the RFR thread (2024-01-23): unloading 60k classes, the "Purge Unlinked NMethods" phase went from about 20 ms to about 60 ms; overall max G1 remark went from 160 ms to 220 ms; remark pauses that unload classes went from 120 ms to 160 ms. Erik suggested G1 "at least run purging concurrently". The thread records no decision. [verified] https://mail.openjdk.org/pipermail/graal-dev/2024-January/006874.html and https://bugs.openjdk.org/browse/JDK-8322630
- Rule of thumb from that thread: about 1 ms of remark latency per 1,000 unloaded classes [verified, quoted in the same thread].

**What is not in JDK 24–26 for G1 [search, negative].** I found no JBS issue or hotspot-gc-dev thread that makes G1 class unloading concurrent. JDK-8333348 (named in the brief) returned a login page, so I could not check it.

**ZGC (what it does instead).**
- ZGC class unloading is concurrent. JDK-8214897 (ZGC: Concurrent Class Unloading) and release note JDK-8218905 say it shipped in JDK 12 and is on by default; -XX:-ClassUnloading turns it off [search]. Earlier JEP 333 (the first ZGC JEP) did not include class unloading in its initial version [verified] https://openjdk.org/jeps/333 .
- JEP 490 (JDK 24): non-generational ZGC is removed, so `-XX:+UseZGC` gives Generational ZGC in JDK 25 [verified] https://openjdk.org/jeps/490 .
- ZGC on macOS/aarch64: JDK-8265702 fixed in JDK 17 b20 [verified] https://bugs.openjdk.org/browse/JDK-8265702 . ZGC on macOS uses mach_vm_remap for its multi-mapping (JEP 364) [search].

---

## A8. Code cache and nmethod metadata

- **Sweeper removed in JDK 20** (JDK-8290025, fixed in b13). [verified] So the sweeper heuristics that SweeperThreshold controlled no longer exist. I could not confirm whether SweeperThreshold and UseCodeCacheFlushing are now obsolete or silently ignored: arguments.cpp special_jvm_flags and the obsolete table were read, and neither flag was found in the read portions [search, open].
- **Nmethod immutable data moved out of CodeCache** (JDK-8331087, integrated April 2024, in JDK 24) [search]. Sub-issue JDK-8373794 (move the nmethod header out of CodeCache) is open. [verified via JDK-8328306 links]
- **Default size:** ReservedCodeCacheSize = 240 MB; users raise it to 512 MB to avoid GC churn when allocation pressure triggers GCs [verified: hotspot-dev RFD below].
- **Segmented code cache** turns on when ReservedCodeCacheSize >= 240 MB [verified, compilerDefinitions summary].
- **Nmethod relocation** JDK-8316694 (Chad Rakoczy, Evgeny Astigeevich): Fixed in JDK 26 b19 (resolved 2025-10-04). It copies and relinks nmethods instead of deoptimise-and-recompile, and it is the base for grouping. [verified] https://bugs.openjdk.org/browse/JDK-8316694
- **Hot-code grouping** JDK-8326205 "Grouping frequently called C2 nmethods in CodeCache": Fixed in JDK 27 b18 (resolved 2026-04-09). Umbrella-like; JEP 8328186 "Hot Code Heap" was closed as a duplicate. [verified] https://bugs.openjdk.org/browse/JDK-8326205
- **Motivation and objections** (hotspot-dev RFD, March 2025, Evgeny Astigeevich): claims 5–15% production gains (JDK 17/21, customer application, not reproducible on Tip), with 10–20% of C2 code actually hot. Vladimir Kozlov: "it will complicate VM existing code for not significant benefits in real production environment." Evgeny: "I think it's better to wait for PoC". [verified] https://mail.openjdk.org/pipermail/hotspot-dev/2025-March/102615.html
- **Tiered compile flags:** not researched in depth. TieredStopAtLevel only shows up in the C1 inlining check (C1InlineStackLimit) in what I read. [verified partial]

---

## A9. Leyden (AOT cache) for a Fabric/Knot application

- **JEP 483 (JDK 24, delivered):** the AOT cache stores classes after read, parse, load and link, so startup skips that work. [verified] https://openjdk.org/jeps/483
  - Non-goal, verbatim: "It is not a goal to cache classes that are loaded by user-defined class loaders." Only classes from the class path, module path and the JDK are cacheable.
  - Fabric's Knot loader is a custom ClassLoader. Minecraft and mod classes loaded through Knot are therefore not cacheable in JDK 25 [estimate from the JEP text; Knot's loader hierarchy not checked].
  - "If a class cannot be AOT-loaded then other, AOT-loadable classes cannot be AOT-linked to it."
  - Measured on Linux x64 in the JEP: HelloStream 0.031 s (JDK 23) vs 0.018 s (JDK 24 with cache), about 42% faster; Spring PetClinic 4.486 s vs 2.604 s, also about 42%. Caches are 11.4 MB and 130 MB.
  - Strict consistency: same JDK build, architecture and OS; class path must match (no directories); module options must match; some JVMTI agents are disallowed.
  - Unsupported with ZGC in JEP 483 (fixed in JEP 516).
- **JEP 514 (JDK 25, delivered):** single-command training. `-XX:AOTCacheOutput=app.aot` for the training run; `-XX:AOTCache=app.aot` for production. JDK_AOT_VM_OPTIONS passes options only to the cache step. The one-step workflow needs about twice the heap size. [verified] https://openjdk.org/jeps/514 (the page does not mention -XX:+AutoCreateSharedArchive or custom loaders).
- **JEP 515 (JDK 25, delivered):** method profiles in the cache. HelloStreamWarmup: 90 ms -> 73 ms (19%) for about 250 KB extra cache (about 2.5%). Only one small example is given. [verified] https://openjdk.org/jeps/515
- **JEP 516 (JDK 26, delivered):** object caching works with any GC, including ZGC. Streamable objects are used when training ran with ZGC, with -XX:-CompressedOops, or with a heap over 32 GB. -XX:+AOTStreamableObjects forces it. [verified] https://openjdk.org/jeps/516 . Not in JDK 25.
- **JEP 544 (integrated in JDK 28):** AOT native code, initially AArch64 and x64 only. Same GC for training and production. Reported on Linux x64: startup reduced 65–80% with AOT code versus 50–70% without. Caches can get large. [verified] https://openjdk.org/jeps/544 . Not in JDK 25.
- **Custom class loaders:** a January 2026 leyden-dev thread says support is under design, with only loaders known to produce stable results expected to be cacheable [search]. I found no release that ships it.

---

## B1. Java2D Metal pipeline (how it is built and loaded)

- Sources: src/java.desktop/macosx/native/libawt_lwawt/java2d/metal has 26 headers, 23 .m files and one shader source, shaders.metal. [verified listing] https://github.com/openjdk/jdk/tree/master/src/java.desktop/macosx/native/libawt_lwawt/java2d/metal
- **Build:** shaders.metal is compiled at JDK build time with the xcrun metal toolchain into shaders.air and then shaders.metallib, which is installed into the JDK lib directory. [search: 2021 RFR for JDK-8260931; the current Awt2dLibraries.gmk path returned 404, so this is from the old review]. A January 2026 MacPorts build log shows that openjdk25 needs a full Xcode install because the metal tool is missing with only the Command Line Tools [search].
- **Load:** the JDK passes the library path (java.home/lib/shaders.metallib) to MTLContext. MTLPipelineStatesStorage calls `[dev newLibraryWithFile:shadersLib error:&error]`; if that is nil it logs and returns nil. [verified in MTLPipelineStatesStorage.m and MTLContext.m, https://raw.githubusercontent.com/openjdk/jdk/master/src/java.desktop/macosx/native/libawt_lwawt/java2d/metal/MTLPipelineStatesStorage.m ] Pipeline creation failure calls NSLog and then `exit(0)`, which kills the JVM. [verified]
- **Runtime compile instead:** replacing newLibraryWithFile with newLibraryWithSource:options:error: (shipping shaders.metal in lib, or embedding it) removes the build-time need for xcrun metal. Cost is runtime compile latency at first use, which can be mitigated with a binary archive cache [estimate; not measured].
- **Default:** Metal has been the Java2D default on macOS since JDK 19 (sun.java2d.metal = true for 19+; false for 17 and 18) [search: Oracle Java 2D properties; JEP 382 said OpenGL stayed the default at 17]. https://docs.oracle.com/en/java/javase/21/troubleshoot/java-2d-properties.html
- Metal in JEP 382 lacks XOR, which the JEP calls out as a niche slowdown. [verified] https://openjdk.org/jeps/382
- Relevance: AWT/Swing drawing. A Minecraft-style game renders through its own native Metal library, so this pipeline is not on the game's hot path [estimate].

---

## B2. Calling Objective-C and Swift from Java

**FFM.** [verified] JEP 454 (JDK 22, final): native linker supports macOS/AArch64 (https://openjdk.org/jeps/454 ). Its stated goal is overhead "comparable to, if not better than, JNI". No benchmark numbers in the JEP.

**Linker.Option (JDK 25 API docs).** [verified] https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/foreign/Linker.Option.html
- `critical(boolean allowHeapAccess)`: the function must be extremely short, must not call back into Java (no upcalls), and may get optimisations. Misuse "is likely to have adverse effects, such as loss of performance or JVM crashes". allowHeapAccess exposes Java heap segments as temporary native addresses.
- `firstVariadicArg(int)`: needed for variadic C functions.
- `captureCallState(String...)` and `captureStateLayout()`: save errno and similar state.
- isTrivial does not appear in the JDK 25 API. It was an earlier preview name and was replaced by critical [search, unverified].
- Downcall cost: an OpenJDK intrinsic patch (JDK-8248331, 2020) reported downcall overhead close to JNI when thread transitions are needed and lower when they are skipped, with JNI blank-call baselines of about 8.5 ns [search, old, not Apple]. For Apple numbers I found nothing [open].

**objc_msgSend from Java.** [search] LWJGL maintainers call objc_msgSend from Java "difficult, ugly and likely slower" and expect FFM to help with varargs. There is no existing public, maintained Java binding to Metal I could find. objc_msgSend is not variadic in the C sense, so each message shape needs a downcall handle with the concrete signature [estimate, consistent with search sources]. An OpenJDK bug report notes objc_msgSend_stret is not used on arm64 [search].

**jextract.** [verified] JDK-8267504 (resolved 2021-05-21): jextract supports only C; -C -xobjc is not supported. The fix makes jextract report the unsupported language and exit. https://bugs.openjdk.org/browse/JDK-8267504 . So jextract cannot generate Objective-C bindings. You need hand-written or generated MethodHandles against objc runtime metadata [estimate].

**Swift.** [search] swiftlang/swift-java (https://github.com/swiftlang/swift-java): jextract for Swift generates Java sources. FFM mode is the default and needs JDK 22+ (validated on JDK 24); a JNI mode was added in 2025 (GSoC) for Android and wider compatibility. It requires Swift 6.1. The Q1 2026 community call listed 95 commits and a planned 0.1 tag. Swift-side export is through C-callable functions (@_cdecl); I did not read the Swift docs for this [open].

**Other bridges** (Rococoa, JNA ObjC, jdk-objc): not researched in this session [open].

---

## B3. What a JDK could provide built in (versus a library)

- **Thread QoS API:** none in the JDK. HotSpot sets no QoS (see A1). Apple's QoS call pthread_set_qos_class_self_np is available from macOS 10.10 and takes an integer relative priority [search: qos.h summary]. The call can be made from Java through FFM with no JDK change. A JDK-level API would need a rationale that JBS JDK-8267720 did not give. Recommendation: library (FFM) first.
- **Thermal state and low-power mode:** NSProcessInfo.thermalState and lowPowerModeEnabled are reachable through the ObjC bridge; a JDK change is not needed [estimate; the Apple doc page had no body text].
- **IOSurface-backed direct buffers:** MemorySegment.ofAddress can wrap an IOSurface base address; a JDK change is not needed. Lifecycle management belongs in the library [estimate].
- **Metal bindings, MTLDevice and command queues:** library. JDK changes would be very hard to maintain across Xcode versions.

---

## C. Apple hardware facts that matter for threads, caches and memory

**Core counts** [verified from Wikipedia tables, https://en.wikipedia.org/wiki/Apple_M1 , Apple_M2, Apple_M3, Apple_M4, Apple_M5]

| Chip | P or super cores | E cores | Total | Notes |
|---|---|---|---|---|
| M1 | 4 | 4 | 8 | |
| M1 Pro / Max | 8 (6 lower bin) | 2 | 10 (8) | |
| M1 Ultra | 16 | 4 | 20 | |
| M2 | 4 | 4 | 8 | |
| M2 Pro | 6 or 8 | 4 | 10 or 12 | |
| M2 Max | 8 | 4 | 12 | |
| M2 Ultra | 16 | 8 | 24 | |
| M3 | 4 | 4 | 8 | |
| M3 Pro | 5 or 6 | 6 | 11 or 12 | |
| M3 Max | 10 or 12 | 4 | 14 or 16 | |
| M4 | 3 or 4 | 4 or 6 | 8, 9 or 10 | binned models disable one P core |
| M4 Pro | 8 or 10 | 4 | 12 or 14 | |
| M4 Max | 10 or 12 | 4 | 14 or 16 | |
| M5 | 4 (super) | 6 | 10 (9 binned) | the wiki calls them super cores |
| M5 Pro | 5 super + 10 perf, or 6 + 12 | none | 15 or 18 | Pro and Max replaced E cores with a new performance core |
| M5 Max | 6 super + 12 perf | none | 18 | |
| M5 Ultra | 10+20 or 12+24 | none | 30 or 36 | |

Caveat: the M5 Pro and Max core labels come from the wiki text and are inconsistent across its tables. Treat M5 Pro/Max core-type details as provisional.

**Cache sizes**
- M1 [verified, Wikipedia]: P core L1 192 KB I / 128 KB D; E core L1 128 KB I / 64 KB D. P-cluster L2 12 MB shared; E-cluster L2 4 MB shared. SLC 8 MB (base).
- M2 [verified]: P core L1 192/128 KB; E core 128/64 KB. P-cluster L2 16 MB (base). E-cluster L2 4 MB. SLC 8 MB (base).
- M3 [verified]: P L2 16 MB (M3, M3 Pro) or 32 MB (M3 Max); E L2 4 MB.
- M4: cache sizes were not in the extracted page text [open].
- M5 [search, lowendmac, unofficial]: super-core L2 16 MB, E-core L2 6 MB, SLC about 32 MB (flagged by the site itself as uncertain).

**Memory bandwidth (theoretical peak)** [verified, Wikipedia]
- M1 68.25 GB/s; M1 Pro 200; M1 Max 400; M1 Ultra 800.
- M2 102.4; M2 Pro 204.8; M2 Max 409.6; M2 Ultra 819.2.
- M3 102.4; M3 Pro 153.6; M3 Max 307.2 (14-core) or 409.6 (16-core).
- M4 120; M4 Pro 273; M4 Max 546 (410 on the binned 32-core GPU model).
- M5 153.6; M5 Pro 307; M5 Max 460 or 614 (by GPU core count); M5 Ultra 1228.8.

**Implications for the runtime**
- Thread counts: HotSpot counts E cores as workers (A1). On a base M1 that is 8 logical CPUs, 8 GC workers and 4 compiler threads. ActiveProcessorCount is the lever (A1, Top 15 item 4).
- Padding and prefetch: macOS reports 128-byte coherence granularity; defaults already follow 128 for prefetch (A3).
- Unified memory: there is one memory pool for CPU, GPU and NPU; no NUMA domains on a single Apple SoC [estimate]. I did not check how HotSpot's NUMA flags are gated, so I cannot confirm they are disabled on macOS.
- Low memory: 8 GB machines have less headroom for the code cache and metaspace; compressed-pointer and compact-header options matter more here (JEP 519 below).
- JEP 519 Compact Object Headers is a product feature in JDK 25 [verified] https://openjdk.org/jeps/519 . JEP-reported gains: one SPECjbb2015 setting used 22% less heap and 8% less CPU; a JSON benchmark ran about 10% faster. Platforms are not listed on the page, so whether macOS/AArch64 is covered is open [open].

**Apple guidance for games.** Apple's public guidance on QoS is in the archived guide (A1). Game Mode activates for a full-screen, front-most app with an appropriate category, per developer forum answers [search]. I found no official Apple document on Game Mode CPU scheduling or on Game Porting Toolkit CPU scheduling [open]. Third-party measurements say Game Mode gives game-category apps priority on E cores [search, single app, Eclectic Light].

---

## Top 15 concrete JDK changes ranked by expected benefit/risk for Minecraft on Apple Silicon

Rank is by benefit adjusted for risk. Items marked (flag) need no code change.

1. **(flag) Turn off G1 class unloading at concurrent mark: -XX:-ClassUnloadingWithConcurrentMark.** What: stops G1 from doing class unloading in Remark (flag from JDK-8048269). Where: G1CollectedHeap::unload_classes_and_code is gated by this flag (see A7). Expected effect: the Remark pause, which is about 98% class unloading in your measurements, falls to a few ms; classes are then unloaded only in full GCs. Risk: metaspace and class-count growth between full GCs; test with long sessions and watch -Xlog:gc+metaspace. High benefit, medium risk.

2. **Defer G1 unload_classes_and_code work out of Remark.** What: run "Purge Unlinked NMethods", "Free Code Blobs" and "Purge Class Loader Data" in a concurrent phase or in the next safepoint, as Erik Österlund suggested in January 2024. Where: g1CollectedHeap.cpp (unload_classes_and_code, complete_cleaning, G1ParallelCleaningTask); g1ConcurrentMark.cpp (remark). Expected effect: most of the 8–78 ms remark tail. Risk: high; nmethod liveness and CLD unloading ordering must stay correct. High benefit, high risk; a research project.

3. **(flag) -XX:+UseCompactObjectHeaders (product in JDK 25).** What: smaller object headers, which helps an 8 GB heap. Where: JEP 519. Expected effect: JEP reports 22% less heap in one SPECjbb case. Risk: low; confirm macOS/AArch64 support and run the Minecraft mod set first. Medium-high benefit, low risk.

4. **(flag) -XX:ActiveProcessorCount=P (P-core count).** What: makes ParallelGCThreads, CICompilerCount and availableProcessors count only P cores. Where: os::active_processor_count honours the flag on macOS (os_bsd.cpp). Expected effect: fewer GC and compile threads, so less E-core use by the VM; a base M1 would get 4 GC workers and 3 compile threads. Risk: fewer GC workers can lengthen young pauses when P cores are busy with the game; Runtime.availableProcessors changes for mods that size pools from it. Medium benefit, medium risk. Measure.

5. **Set QoS for JVM-internal threads.** What: call pthread_set_qos_class_self_np (or pthread_attr_set_qos_class_np at creation) in JavaThread/GangWorker/CompilerThread startup; for example GC workers to user-initiated, compiler threads to utility so they prefer E cores. Where: os_bsd.cpp thread-start path (the os::create_thread equivalent, in os_linux.cpp per the comment), plus the GC worker and compiler thread run() entry points. Expected effect: frees P cores for the render thread; the sign of the GC pause effect is unknown. Risk: priority inversion (a GC worker at utility could slow pauses), and JDK-8267720 was closed Won't Fix. Medium-high potential, medium risk. Needs measurement.

6. **Backport lazy W^X (JDK-8328306).** What: execute-enabled by default, write on demand; the author claims up to 90% fewer switches. Where: os_cpu/bsd_aarch64/os_bsd_aarch64.cpp (current_thread_enable_wx), threadWXSetters, interfaceSupport.inline.hpp and the other ThreadWXEnable sites. Expected effect: removes up to ~50 ns per switch on transition-heavy and JIT-heavy code. Risk: high; the fix history includes a SIGBUS healing path, StressWXHealing guarantees and a VM-shutdown PerfTraceTime bug (JDK-8377413/8377425/8377948) that must come with it. Medium-high benefit, high risk.

7. **Fine-grained W^X placement (the lower-risk form of item 6, JDK-8307817 idea).** What: move the expensive ThreadWXEnable locks (for example the one in interfaceSupport.inline.hpp) down to the code that writes the code cache, as was done for Math.log in JDK-8302736. Expected effect: removes the 7x Math.log class of regression where it still exists. Risk: medium-low, only where writes are narrow. Medium benefit, low-medium risk.

8. **(flag) Use Leyden AOT for JDK and classpath classes (JEP 514 + JEP 515).** What: run once with -XX:AOTCacheOutput, production with -XX:AOTCache. Expected effect: startup (42% on JEP 483's examples on Linux x64) and warm-up (19% on JEP 515's small example). Knot-loaded classes are not cached, so the gain for a Fabric launch is probably small. Risk: low; cache is strictly tied to JDK build and classpath. Medium benefit for startup, low risk.

9. **Custom-class-loader support in the AOT cache (Knot).** What: allow classes from loaders known to be stable (leyden-dev design, January 2026). Where: AOT cache dump/load code (leyden work in the Leyden tree; not checked). Expected effect: the largest startup win for a Fabric launch, because most game classes are Knot-loaded. Risk: high; it is open design work. High benefit, high risk.

10. **Uncommit code-cache pages with MADV_FREE_REUSABLE on macOS.** What: in os::pd_uncommit_memory (macOS exec branch), use MADV_FREE_REUSABLE (or drop the pages with a remap as the non-exec branch does). Where: os_bsd.cpp. Expected effect: phys_footprint drops at uncommit, not later under pressure. Risk: low-medium; verify accounting with footprint tools. Low-medium benefit, low risk.

11. **Apple defaults in vm_version_aarch64.cpp.** What: add CPU_APPLE to the vendor tables (UseSIMDForMemoryOps = true, AvoidUnalignedAccesses per measurement; OnSpinWaitInst per measurement). Where: vm_version_aarch64.cpp (vendor switch in VM_Version::initialize). Expected effect: small, unmeasured. Risk: low, but each default needs benchmarks. Low benefit, low risk.

12. **Backport nmethod relocation and hot-code grouping (JDK-8316694, JDK-8326205).** What: relocate nmethods (JDK 26) and group hot C2 code in its own heap (JDK 27). Where: nmethod.cpp, codeCache.cpp, the HotCodeCollector sampler. Expected effect: reduces code-cache sparsity; claimed 5–15% on a customer server application, not reproduced. Risk: high; many follow-up bugs (JDK-8369147, 8370527, 8371046 and others) and the maintainers doubt the benefit. Uncertain benefit, high risk.

13. **Generational ZGC as the default collector for this JDK.** What: not a change; ZGC already does concurrent class unloading and has no G1-style Remark (A7). Where: JEP 490 (JDK 25 default is generational). Expected effect: removes the Remark class-unloading cost entirely. Risk: throughput and memory overhead on 8 GB; your notes say G1 with HeapTrim was measured against ZGC before. Medium benefit, medium risk. Measure before rejecting.

14. **A JDK-level QoS API for Java threads.** What: a java.lang.Thread method that sets QoS. Where: new native hook in os_bsd.cpp plus a Java API. Expected effect: none on its own; it lets the game choose QoS per thread. Risk: API design and maintenance; JDK-8267720 rejected the broader idea. Low benefit, low risk; better as a library through FFM.

15. **Keep cache-line defaults; do not change DEFAULT_CACHE_LINE_SIZE.** What: no change. Where: globalDefinitions_aarch64.hpp (64), vm_version_bsd_aarch64.cpp (sysctl 128). Expected effect: none. Risk: none. Listed to record the decision that a 128-byte prefetch granule already comes from sysctl and the padding is already 128.

---

## Answers (short)

- A1: No QoS in HotSpot. The GC and JIT thread counts come from hw.ncpu (P and E). ActiveProcessorCount is honoured on macOS. CICompilerCount for 8 cores is 4.
- A2: W^X toggles with pthread_jit_write_protect_np; cost up to ~50 ns per switch (JBS claim); lazy switching is JDK 27 only.
- A3: 64-byte compile-time line, 128 for padding; the runtime value on macOS is 128 from sysctl; L1 line size is disputed.
- A4: 16 KB native pages; large pages are not supported on macOS.
- A5: Code cache uncommit uses MADV_FREE; heap uncommit remaps with PROT_NONE. No macOS footprint JBS issue found.
- A6: CPU features come from sysctl hw.optional.arm.*; several defaults (SIMD memory ops, unaligned access, spin-wait) are not tuned for Apple.
- A7: Remark unload work is G1 Complete Cleaning and purges, parallel on active workers. The 2024 measurements show the purge cost; no concurrent G1 unloading exists in JDK 24–26 per my search.
- A8: Sweeper gone since 20; relocation in 26; hot-code grouping in 27.
- A9: JEP 483/514/515 are JDK 24/25; JEP 516 is JDK 26; JEP 544 is JDK 28; custom loaders are not cached in JDK 25.
- B1: Metal shaders are compiled at build time to shaders.metallib and loaded with newLibraryWithFile; runtime compile is possible. Metal is the default since JDK 19.
- B2: FFM critical option exists; jextract does not do ObjC; Swift via swift-java jextract in FFM or JNI mode.
- B3: Keep QoS, thermal state and Metal in a library through FFM.
- C1: Core counts and caches in the table above.
- C2: Bandwidth in the table above.
- C3: Unified memory, no NUMA on a single SoC [estimate]; Apple's game guidance is QoS and Game Mode, not a public scheduler spec.

---

## Open questions

1. Does pthread_set_qos_class_self_np or a new thread inherit QoS from the java launcher main thread? Needs a test on a real Mac.
2. What is the exact L1D and L2 line size on M1–M5? sysctl says 128; L1 is disputed. A microbenchmark (not run here) would settle it.
3. Apple's DCZID_EL0 value (is DC ZVA 64 or 128 bytes?) decides whether UseBlockZeroing is active.
4. Does vm_version set UseLSE and UseCRC32 for Apple (the code path was partly read)?
5. Does JEP 519 (Compact Object Headers) support macOS/AArch64 in JDK 25? The JEP page does not list platforms.
6. SweeperThreshold and UseCodeCacheFlushing: obsolete, ignored or still active in JDK 25? Needs the special_jvm_flags/obsolete table in arguments.cpp beyond the read range.
7. JDK-8333348 (named in the brief) could not be read. JBS returned a login page.
8. Is there a G1 change in JDK 25 for concurrent purging? My searches found none, but the search was not exhaustive.
9. What is the Knot class-loader topology, and does the Leyden custom-loader design cover it?
10. M4 and M5 L2/SLC sizes were not in the extracted text. M5 numbers are from an unofficial site.
11. Does Java2D Metal's compile-at-runtime path (newLibraryWithSource) add startup cost that matters? Not measured.
12. Are objc_msgSend FFM calls on arm64 cheaper with Linker.Option.critical? Not measured; no Apple-specific benchmark found.
13. Rococoa, JNA ObjC and jdk-objc were not researched.
14. Apple's Game Mode and Game Porting Toolkit scheduling: no official Apple document returned text.
15. Does ZGC or Generational ZGC on macOS/AArch64 in JDK 25 have a different class-unloading or footprint cost? Not measured.

---

## Source list (main)

- os_bsd.cpp: https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/os/bsd/os_bsd.cpp
- os_bsd_aarch64.cpp: https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/os_cpu/bsd_aarch64/os_bsd_aarch64.cpp
- vm_version_bsd_aarch64.cpp: https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/os_cpu/bsd_aarch64/vm_version_bsd_aarch64.cpp
- vm_version_aarch64.cpp: https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/cpu/aarch64/vm_version_aarch64.cpp
- globals_aarch64.hpp, globalDefinitions_aarch64.hpp: https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/cpu/aarch64/
- workerPolicy.cpp, compilationPolicy.cpp, gc_globals.hpp: https://raw.githubusercontent.com/openjdk/jdk/master/src/hotspot/share/
- G1CollectedHeap at tag jdk-25+36: https://github.com/openjdk/jdk/blob/jdk-25+36/src/hotspot/share/gc/g1/g1CollectedHeap.cpp
- JBS: JDK-8267720, JDK-8273121, JDK-8302736, JDK-8307817, JDK-8317809, JDK-8316694, JDK-8326205, JDK-8322630, JDK-8328306, JDK-8330171, JDK-8359463, JDK-8027543, JDK-8048248, JDK-8290025, JDK-8265702, JDK-8267504
- Mail: graal-dev 2024-01 (RFR 8322630), hotspot-dev 2025-03 (grouping hot code RFD)
- JEPs: 333, 382, 454, 483, 490, 514, 515, 516, 519, 544
- Apple archived QoS guide: https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/PrioritizeWorkWithQoS.html
- Wikipedia Apple M1, M2, M3, M4, M5 pages
- Oracle: Linker.Option (JDK 25 javadoc), Java2D properties (JDK 21 page)
- Third-party (search only): https://eclecticlight.co/2024/12/17/tune-for-performance-core-types/ ; https://cpufun.substack.com/p/more-m1-fun-hardware-information ; https://lowendmac.com/2026/apple-silicon-m5-chip-specs/
