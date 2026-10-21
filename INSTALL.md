# Using Vivace with Minecraft (macOS, Apple Silicon)

Two downloads; either works:
- `vivace-VERSION-macos-aarch64-runtime.tar.gz` (57 MB): a runtime with what Minecraft, Fabric and common mods need. For
  playing.
- `vivace-VERSION-macos-aarch64-jdk.tar.gz` (222 MB): the full JDK (compiler and tools included). For modding.

## 1. Unpack
Double-click the .tar.gz (or `tar -xzf FILE`). You get a folder ending in `.jdk`. Put it somewhere permanent, for example
`~/Library/Java/JavaVirtualMachines/` (create the folder if needed; macOS then lists it in `/usr/libexec/java_home -V`).

The builds are signed ad hoc, not notarized by Apple (that needs a paid Apple developer account). If macOS says the
program "can't be opened" or "is damaged", remove the download quarantine once:

    xattr -dr com.apple.quarantine ~/Library/Java/JavaVirtualMachines/Vivace-*.jdk

## 2. Point your launcher at it (menu names may differ between launcher versions)
The Java program is `Vivace-....jdk/Contents/Home/bin/java`.
- **CurseForge**: Settings > Minecraft > Java Settings (or the profile's own settings): uncheck "Use the recommended Java"
  if shown, and choose the `java` file above.
- **Prism Launcher**: the instance's Settings > Java > Browse, choose the `java` file (Prism checks it and shows
  "25.0.5" by Vivace).
- **Official launcher**: Installations > the installation > More Options > Java Executable: the `java` file.
- **Modrinth App**: the profile's Settings > Java and memory > Custom Java installation.

## 3. Check
In game, F3 shows `Java: 25.0.5 ...`; the launcher log or `java -version` says `Vivace-25.0.5.1`.

## What changes
Shorter, rarer garbage-collection pauses (PATCHES.md): G1's class-unloading work in only some marking cycles (with the
Cadence mod: in menus), and the JVM's own threads scheduled on the right Apple cores. Everything else is OpenJDK 25.0.5.
To go back, point the launcher at its own Java again.
