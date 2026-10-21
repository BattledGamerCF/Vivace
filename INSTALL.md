# Using Vivace with Minecraft (macOS, Apple Silicon)

Two downloads; either works:
- `vivace-VERSION-macos-aarch64-runtime.tar.gz` (about 60 MB): a runtime with what Minecraft, Fabric and common mods need.
  For playing.
- `vivace-VERSION-macos-aarch64-jdk.tar.gz` (about 220 MB): the full JDK (compiler and tools included). For modding.

Minecraft 26.3 runs on Vivace 25 and Vivace 27. Vivace 27 is the newer line (G1 from JDK 27: about a quarter less heap
and half as many long pauses in Cadence's tests); Vivace 25 is there for anything that needs Java 25 exactly.

## 1. Unpack
Double-click the .tar.gz (or `tar -xzf FILE`). You get a folder ending in `.jdk`. Put it somewhere permanent:
- `~/Library/Application Support/Vivace/` (create the folder): only programs that look there use it (Cadence does).
- or `~/Library/Java/JavaVirtualMachines/`: macOS then lists it as an installed Java (`/usr/libexec/java_home -V`), and if
  it is the newest Java there, Terminal's `java` command starts using it.

The builds are signed ad hoc, not notarized by Apple (that needs a paid Apple developer account). If macOS says the
program "can't be opened" or "is damaged", remove the download quarantine once (adjust the folder):

    xattr -dr com.apple.quarantine ~/Library/Application\ Support/Vivace/Vivace-*.jdk

## 2a. With the Cadence mod: nothing to set in the launcher
Video Settings > Cadence: Extras > **Java: Vivace**, then restart Minecraft. Cadence finds the newest Vivace in the two
folders above, checks that it accepts your launcher's Java arguments, and restarts the game on it at the very start of
loading. If anything is wrong (Vivace missing, an argument it refuses, macOS blocking it), the game runs on the launcher's
Java and the settings screen says why. `cadence.java=/path/to/Vivace-....jdk` in config/cadence.properties picks a
specific one.

## 2b. Without Cadence: point your launcher at it (menu names may differ between launcher versions)
The Java program is `Vivace-....jdk/Contents/Home/bin/java`.
- **CurseForge**: Settings > Minecraft > Java Settings (or the profile's own settings): uncheck "Use the recommended Java"
  if shown, and choose the `java` file above.
- **Prism Launcher**: the instance's Settings > Java > Browse, choose the `java` file (Prism checks it and shows the
  version "by Vivace").
- **Official launcher**: Installations > the installation > More Options > Java Executable: the `java` file.
- **Modrinth App**: the profile's Settings > Java and memory > Custom Java installation.

## 3. Check
In game, F3 shows the Java version; Cadence's Benchmark card says e.g. `Java: 27.0.1 · Vivace-27.0.1.1`; the launcher log
or `java -version` says `Vivace-...`.

## What changes
Shorter, rarer garbage-collection pauses (PATCHES.md): G1's class-unloading work in only some marking cycles (with the
Cadence mod: in menus), the JVM's own threads scheduled on the right Apple cores, compact object headers on. Everything
else is OpenJDK. To go back, set Java: Launcher's in Cadence, or point the launcher at its own Java again.

## Licence
GPLv2 with the Classpath Exception, like OpenJDK; the source is on the same release page (README.md). Running Minecraft or
mods on Vivace doesn't change their licences. Java and OpenJDK are trademarks or registered trademarks of Oracle and/or
its affiliates; Vivace is based on the OpenJDK source code and is not made or endorsed by Oracle.
