# Vivace (working name): an OpenJDK 25 build tuned for games on Apple Silicon Macs

A build of OpenJDK 25 (from the upstream jdk25u repository, the same source Azul's Zulu 25 builds come from) with a small
set of measured patches for games, Minecraft first: shorter and rarer garbage-collection pauses on Apple Silicon. Made to
pair with the Cadence Minecraft mod, but it is a separate download and works without it.

Not affiliated with Oracle, Azul or the OpenJDK project. Not tested with the Java SE TCK, so it makes no claim of Java SE
compatibility. The name is a working name: no trademark search has been done (research/LEGAL.md).

## Layout
| Path | What |
|---|---|
| `PATCHES.md` | Every change, why, and what it measured |
| `PLAN.md` | The plan and status |
| `research/` | BUILD.md (building and forking), APPLE.md (Apple Silicon and HotSpot), LEGAL.md (licences, trademarks, names) |
| `build-tools/` | Stand-ins for Xcode's `metal`/`metallib` so the JDK builds with the Command Line Tools only |
| `src/` | OpenJDK jdk25u checkout (own git repository; not in this one) at jdk-25.0.2+10 = the A/B baseline |
| `src-game/` | worktree, branch `game`: patches on 25.0.2 (experiments, A/B) |
| `src-release/` | worktree, branch `vivace-25.0.5`: patches on jdk-25.0.5-ga, what ships |
| `out/` | built JDK images (baseline, qos, unload, ...) |

## Licence
OpenJDK is GPLv2 with the Classpath Exception. Every binary release ships with the complete corresponding source (the
`vivace-25.0.5` branch as a source archive) and keeps the JDK's `legal/` notices; modified files carry change notices.
