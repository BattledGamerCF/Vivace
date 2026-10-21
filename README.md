# Vivace (working name): an OpenJDK build tuned for games on Apple Silicon Macs

A build of OpenJDK 25 (and 27) from the upstream jdk25u / jdk27u repositories (the same sources Azul's Zulu and other
builds come from) with a small set of measured patches for games, Minecraft first: shorter and rarer garbage-collection
pauses on Apple Silicon. Made to pair with the Cadence Minecraft mod, but it is a separate download and works without it.

Not affiliated with Oracle, Azul or the OpenJDK project. Not tested with the Java SE TCK, so it makes no claim of Java SE
compatibility. The name is a working name: no trademark search has been done (research/LEGAL.md).

## Layout
| Path | What |
|---|---|
| `PATCHES.md` | Every change, why, and what it measured |
| `PLAN.md` | The plan and status |
| `research/` | BUILD.md (building and forking), APPLE.md (Apple Silicon and HotSpot), OPTIMIZE.md (HotSpot tuning), LEGAL.md and LEGAL2.md (licences, trademarks, names, running mods on Vivace) |
| `build-tools/` | Stand-ins for Xcode's `metal`/`metallib` so the JDK builds with the Command Line Tools only; `build-release.sh` (`SRC=src27 BOOT=src26/build/boot/images/jdk BUILD_NUM=9` for 27) |
| `src/` | OpenJDK jdk25u checkout (own git repository; not in this one) at jdk-25.0.2+10 = the A/B baseline |
| `src-game/` | worktree, branch `game`: patches on 25.0.2 (experiments, A/B) |
| `src-release/` | worktree, branch `vivace-25.0.5`: patches on jdk-25.0.5-ga (Vivace 25) |
| `src26/` | jdk26u at jdk-26.0.2.1-ga, unpatched: the boot JDK for building 27 (`build/boot/images/jdk`) |
| `src27/` | jdk27u at jdk-27.0.1-ga, branch `vivace-27.0.1`: the same patches (Vivace 27); branch `exp-compiler-qos`: the two experiments not kept (PATCHES.md) |
| `dist/` | one folder per release: jdk, runtime and source archives, SHA256SUMS, docs |
| `out/` | built JDK images (baseline, qos, unload, ...) and jtreg results |

## Licence and trademarks
- OpenJDK is GPLv2 with the Classpath Exception (HotSpot itself is GPLv2 only); Vivace's changes are under the same terms
  as the files they change. Every binary release has the complete corresponding source next to it on the same page: the
  release branch as a source archive, plus `vivace/` with the scripts that build it (build-tools/) and these docs. Every
  module keeps its `legal/` notices (LICENSE, ASSEMBLY_EXCEPTION, ADDITIONAL_LICENSE_INFO, third-party notices); every
  modified file carries a change notice (GPLv2 2(a)) and PATCHES.md lists each change. No extra terms, no click-through.
- Java and OpenJDK are trademarks or registered trademarks of Oracle and/or its affiliates. Vivace is based on the OpenJDK
  source code and is not affiliated with or endorsed by Oracle, the OpenJDK project or Azul. `java -version` keeps
  upstream's wording ("openjdk version", "OpenJDK Runtime Environment Vivace-..."), as other OpenJDK builds do: the
  OpenJDK Trademark Notice allows the name in version strings for a substantially complete build whose code is a vast
  majority identical to upstream (Vivace changes 10-11 files, about 150 lines), and launchers read that text.
- Problems with Vivace go to the Vivace/Cadence issue tracker (java.vendor.url.bug and the crash-report link say so), not to
  Oracle or OpenJDK: they didn't make these changes.

## For programs that run on Vivace (mods, games)
Running a program on Vivace puts no licence obligation on that program: a JVM runs the program as data, the class
libraries it calls carry the Classpath Exception, and the program contains no Vivace code (research/LEGAL2.md; not legal
advice). The Cadence mod (Apache-2.0) keeps to that: it starts an installed Vivace only when the player chooses it,
through exec and public Java APIs (HotSpotDiagnosticMXBean, the release file), and never ships, downloads or links any
part of it. Ship Vivace as its own download, never inside a mod jar or modpack.
