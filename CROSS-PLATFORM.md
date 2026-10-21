# Windows and Linux (theoretical: nothing here has been built or run on those systems)

## What carries over
| Patch | macOS | Windows / Linux |
|---|---|---|
| Build without Xcode (Java2D shaders) | used | not compiled (the Metal files are macOS-only) |
| UseThreadQoS | on | not compiled (`#ifdef __APPLE__` in os_bsd.cpp; Windows and Linux use os_windows.cpp / os_linux.cpp) |
| G1ClassUnloadingInterval | on | **the same code**: shared HotSpot G1 code, so it builds and behaves the same on every OS |

So the GC improvement Minecraft feels most (Remark pauses only every Nth cycle, or in menus with Cadence's GC policy) is
portable as is; only the Apple core scheduling is Mac-specific.

## How the other builds would be made
OpenJDK's own GitHub Actions run on forks: pushing the `vivace-25.0.5` branch to a GitHub fork of openjdk/jdk25u starts
`.github/workflows/main.yml`, which builds linux-x64, linux-aarch64 (cross), windows-x64 and macos-aarch64 with the
reusable build-linux.yml / build-windows.yml / build-macos.yml (Visual Studio 2022 + MSYS2 on Windows, gcc on Ubuntu 24.04)
and runs tier1 tests. Its artifacts are the Windows and Linux builds. Branding (vendor name, version) is passed to
configure the same way as build-tools/build-release.sh does on the Mac.

Known differences to check when someone can run them:
- macOS builds here use the stand-in metal tools; GitHub's macOS runners have Xcode, so the CI macOS build compiles the real
  shaders.metallib (the loader patch only matters when the file is source).
- Windows: the VC++ runtime DLLs bundled in the image fall under Microsoft's redistribution terms (research/LEGAL.md).

## Platform equivalents of UseThreadQoS (not implemented)
- Windows 11: EcoQoS (SetThreadInformation with THREAD_POWER_THROTTLING_EXECUTION_SPEED) would send concurrent GC threads to
  efficiency cores on hybrid Intel CPUs; the stop-the-world workers would keep normal scheduling.
- Linux: `SCHED_IDLE`/nice for concurrent GC threads; on hybrid CPUs, utilization clamping (sched_setattr uclamp_max).
These need a machine of each kind to measure; until then the macOS QoS code stays macOS-only.
