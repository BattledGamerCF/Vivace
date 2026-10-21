# LEGAL2.md: running Cadence (Apache-2.0) on Vivace (GPLv2 + CPE), and how to ship it

Date: 2026-10-21. Author: Haiku 5.5 research agent; saved and lightly condensed by the main session.
Read research/LEGAL.md (2026-10-20) first; this file answers the follow-up questions.
Not legal advice. Tags: [verified] = primary page or source file read; [search] = secondary or search
excerpt; [estimate] = reasoning. Items marked [search] or [estimate] need checking before release.

## Bottom line

Running an Apache-2.0 mod and the proprietary Minecraft client on Vivace does not, by itself, put
GPL obligations on either program. GPL duties attach to *Vivace's own distribution* (source, licence,
notices, trademark wording). The real risks are platform moderation, trademark wording and macOS
signing, not the GPL.

## 1. GPL and the Classpath Exception

- Classpath Exception [verified, openjdk.org/legal/gplv2+ce.html]: permits linking the library "with
  independent modules to produce an executable, regardless of the license terms of these independent
  modules". A modified library *may* extend the exception to its version but is not obliged to.
  Vivace keeps every CE header unchanged.
- ASSEMBLY_EXCEPTION [verified, openjdk/jdk master]: lets the package be distributed together with
  independent programs under other licences (Apache-2.0 named), but forbids *commingling* code under an
  incompatible licence with the GPLv2 code.
- FSF GPL FAQ [verified, gnu.org/licenses/gpl-faq.html]:
  - Interpreters: a program run by an interpreter "is just data"; the GPL cannot limit what data
    the interpreter runs.
  - Bindings caveat: if the interpreter adds bindings to *GPL* facilities, programs using them are
    effectively linked to those facilities. (In the JDK, those bindings are CPE-covered.)
  - Aggregates: separate programs on the same medium are allowed even under incompatible licences.
  - Pipes, sockets, command-line arguments and simple fork/exec mean separate programs.
  - The "system library" exception covers OS components, not a JVM shipped by Vivace.
- GPLv2 section 2: "mere aggregation" of another work does not bring it under the licence
  [verified via FAQ].
- Apache-2.0 is incompatible with GPLv2 (it is compatible with GPLv3) [verified, gnu.org licence list].
- HotSpot vs class libraries [verified, jdk-25.0.5-ga headers]:
  - `src/hotspot/share/runtime/java.cpp` is "GPL version 2 only", with no CE.
  - `java/lang/Object.java` carries the CE designation.
  - Simonis on discuss@ (2019) [search]: almost all of src/hotspot is GPL-only; the CE targets normal
    use cases of running Java applications on OpenJDK.
- The missing CE on HotSpot does not reach programs that *run on* it. GPL reach follows copying and
  linking, not running. It matters only if a program incorporates or links HotSpot code, or if Apache
  code is patched into Vivace.

Verdict [estimate]: Cadence and Minecraft carry no GPL obligation from running on Vivace.

Rule: never compile or link Cadence code into Vivace, and never put Apache-2.0 code into Vivace's
GPLv2 sources. Vivace's own patches are GPLv2 (they already are: same headers as the files they touch).

## 2. Calling Vivace-only VM options from the mod

- HotSpotDiagnosticMXBean (`setVMOption`) is a documented public API. Unknown, invalid or non-writable
  options throw IllegalArgumentException [verified, JDK 25 javadoc].
- HotSpotDiagnosticMXBean.java and its native glue HotSpotDiagnostic.c both carry the CE
  [verified]. The glue reaches the VM only through the jmm interface function table.
- So setting `G1ClassUnloadingInterval` (a MANAGEABLE flag) from Cadence is interface use, not a
  derivative work. The closest counterpoint is the FAQ's "bindings" paragraph, but here the binding
  layer is CE-covered JDK code.
- Practical rules:
  - No HotSpot headers.
  - No copied VM structs.
  - No `dlsym` into libjvm.
  - Only documented MXBean, ProcessBuilder/exec and public FFM calls.
  - Vivace-only options stay optional, with graceful fallback when the option is absent. GcPolicy
    already does this.

## 3. Distribution models

| Model | GPL | Platforms | Verdict |
|---|---|---|---|
| (a) Vivace on its own GitHub Releases page, with source on the same page | Distributor gives source "on the same server" [verified FAQ]; the mod has no duty | Modrinth allows relevant public links (rule 5.4); CurseForge forbids *external download links for files* | **Recommended** |
| (b) Mod detects a user-installed Vivace and re-execs the game under it | exec = separate programs [verified FAQ]; no duty on the mod | No rule against it found. Precedent: Relauncher (MPL-2.0, execvp, Java 8-25) is on Modrinth/CurseForge [verified] | **Recommended**, with the user choosing it (opt-in) |
| (c) Mod auto-downloads Vivace | Fine if fetched from Vivace's own release; if Cadence hosts or mirrors it, Cadence becomes a GPL distributor | CurseForge bans external download links for files; Modrinth 1.11 requires disclosure of any data sent. Precedent: Improved Cleanroom Relauncher auto-downloads Adoptium [verified] | **Defer** (needs moderator confirmation; consent, HTTPS, pinned SHA-256) |
| (d) Vivace bundled in the mod jar or zip | Allowed as an aggregate if source, licence and notices ride along | CurseForge files must be jars; Modrinth "additional files" are for special purposes; Apple needs nested code signed | **Not for v1** (size, notarisation, moderation) |
| (e) Modpack declares Vivace | - | .mrpack has no Java field; download URLs limited to Modrinth/GitHub/GitLab [verified]; CurseForge manifest Java field not found [search] | Packs can *recommend* it in docs only |

## 4. Platform rules (Modrinth, CurseForge)

- Modrinth [verified, modrinth.com/legal/rules]:
  - 1.11: no uploading data to remote servers without clear disclosure.
  - 1.12: no bypassing Mojang server restrictions.
  - 2: honest descriptions.
  - 4: licensing and permissions.
  - 5.4: external links must be public and relevant.
  - 5.7: "additional files" only for designated purposes.
  - No rule on runtimes or re-executing the game. No "runtime" project type exists, so Vivace should
    not be listed on Modrinth as a project.
- CurseForge [verified, support articles 9000197279, 9000197908]:
  - "External download links for files are not allowed".
  - Projects must follow the game's EULA/ToS.
  - Non-CurseForge mods in packs must be on the approved list (MIT/GPL or equivalent).
- Precedents:
  - Relauncher (execvp relaunch) [verified].
  - Improved Cleanroom Relauncher (auto-download JRE) [verified].
  - Prism Launcher per-instance Java and auto-download Mojang Java [verified wiki].
  - Precedent is not permission.

## 5. Minecraft EULA

- Primary text not retrieved: minecraft.net timed out every time.
- Secondary summaries [search]:
  - Mods allowed if original and free of substantial Mojang code.
  - Game downloads must come from an authorised source.
  - Tools must not appear official.
- No clause found about running the game on another JVM. Users do this routinely through every
  launcher's Java setting.
- Rules for Cadence:
  - Never ship Minecraft files.
  - Never present Vivace or Cadence as official.
  - Leave Mojang's files untouched on disk.

## 6. GPL, licence and trademark checklist for Vivace releases

- Source:
  - Same release page as the binaries [verified FAQ].
  - Complete corresponding source plus build scripts, the exact base tag and the patch series.
  - With source alongside, no written offer is needed.
- Keep LICENSE, ASSEMBLY_EXCEPTION, ADDITIONAL_LICENSE_INFO, `legal/` and every CE header. Ship the
  licence with every copy.
- Modification notices (GPLv2 2(a)): prominent notices of changes. Vivace has these: per-file
  "Modified for Vivace" notices plus PATCHES.md.
- No further restrictions (GPLv2 s6): no EULA or click-through on Vivace.
- OpenJDK trademark notice v1.22 [verified]:
  - "OpenJDK" may appear in package names and version strings only for a substantially complete
    implementation whose code is a vast majority identical to upstream from a single site.
  - Otherwise only nominative use such as "based on the OpenJDK source code".
  - Include the legend "Java and OpenJDK are trademarks or registered trademarks of Oracle and/or its
    affiliates."
  - "OpenJDK" should be used only as an adjective [search, Reinhold 2018].
- Don't use "Java" in the product name. Don't claim Java SE compatibility (that needs the TCK/OCTLA).
- macOS:
  - The linker ad-hoc signs arm64 binaries (JDK-8270199) [verified].
  - Ad-hoc signatures do not pass Gatekeeper for quarantined downloads.
  - Notarisation needs a Developer ID, hardened runtime, timestamp, nested code signed first, and a
    stapled .dmg/.pkg (not a zip) [verified, Apple docs].
  - Typical JVM entitlements: allow-jit, allow-unsigned-executable-memory,
    disable-library-validation (AdoptOpenJDK 2020) [verified].
  - curl downloads are not quarantined; browser downloads are [search].

## 7. The name "Vivace"

- No live class 9/42 (software) VIVACE registration found [search].
- One live VIVACE in class 25 (clothing, Reg. 3074532).
- Several abandoned 1990s software filings.
- "Viva" was a dormant 2003 SourceForge JVM.
- Not searched: EUIPO, UK, WIPO, Japan, China. A formal clearance search is needed before any public
  launch.

## Recommended design (agent's list, main session's notes in brackets)

1. Vivace is its own product: per-platform archives on GitHub Releases, each with source, LICENSE,
   ASSEMBLY_EXCEPTION, ADDITIONAL_LICENSE_INFO, legal/ and a change list. [build-release.sh already
   produces jdk/runtime/src tarballs + SHA256SUMS + PATCHES/README/INSTALL.]
2. Trademark-safe strings: "Vivace 25.0.5", "based on OpenJDK 25.0.5", plus the Oracle legend.
   [Audit `java -version` output: see section "Version strings" below.]
3. macOS: Developer ID signing and notarisation before public release. [Needs the user's Apple
   developer account; currently ad-hoc + hardened runtime, so it is fine for local use.]
4. Keep Cadence clean: no HotSpot code or headers; MXBean, exec and FFM only. [True today.]
5. v1: relaunch, not auto-download. The user picks Vivace (or Cadence finds it in the standard JVM
   folders and asks). Validate with the `release` file, guard against loops, fall back on failure.
6. Listings: on Modrinth, a relevant GitHub link is fine. On CurseForge, describe Vivace in text and
   point to the README; confirm with moderators.
7. No bundling in the jar or modpacks.
8. Auto-download deferred: opt-in, consent, HTTPS GitHub, pinned SHA-256, moderator review first.
9. Read the Minecraft EULA in full before release.
10. Formal trademark search on "Vivace".
11. Counsel: the bindings reading, the trademark condition, GPLv2 s2/s6 text, auto-download.

## Open questions

1. Primary Minecraft EULA text.
2. Exact GPLv2 s2(a), s3, s6 wording (gnu.org rate-limited).
3. The bindings reading for MXBean calls into HotSpot.
4. Whether CurseForge treats a text mention of a GitHub release as an external download link.
5. CurseForge manifest Java field.
6. The "vast majority identical" trademark condition.
7. Gatekeeper on execve of a quarantined binary (test on macOS 15+).
8. Prism and other launchers' per-instance Java keys.
9. Mojang launcher version checks with a user-chosen JVM.
10. Windows and Linux distribution rules (not researched).

---

# Legal pass: what was decided and done (main session, 2026-10-21)

## How Cadence runs on Vivace: the chosen model
**(a) + (b): Vivace is its own download; Cadence restarts the game on an installed Vivace only when the player chooses it.**
- Cadence: Video Settings > Java: Launcher's / Vivace (off by default; `cadence.java=` for hand config). At the start of
  loading, the restart Cadence already does for its Java defaults (execve, same process) goes to Vivace's `java`.
- Separate programs: exec, the release file, `-version`, and one documented MXBean call (setVMOption on a MANAGEABLE flag).
  No HotSpot headers, no libjvm symbols, no Vivace code in the jar; nothing downloaded, nothing bundled.
- Consent and fallback: off unless chosen. Before switching, a `-version` probe with the player's -XX options. Refused
  option, quarantine block, or a start that never reached the game: the launcher's Java is used and the settings screen
  says why. Found in ~/Library/Application Support/Vivace (doesn't change Terminal's default `java`) or the system Java
  folders.
- Tested: 15 offline checks (tools/logic-tests/VivaceCheck.java); live, a Zulu 25 launch restarted onto Vivace 27.

## GPL compliance of Vivace releases: checklist status
| Item | Status |
|---|---|
| Complete corresponding source next to the binaries | yes: `-src.tar.xz` of the release branch |
| Scripts that control compilation (GPLv2 s3) | **fixed today**: the source archive now also holds `vivace/build-tools/` (release script, metal/metallib stand-ins) and the docs |
| Change notices in modified files (s2(a)) | yes: every modified file, both lines; PATCHES.md lists each change |
| LICENSE, ASSEMBLY_EXCEPTION, ADDITIONAL_LICENSE_INFO, third-party notices | yes: `legal/<module>/` in the JDK and the runtime (checked in the 27 runtime) |
| Classpath Exception headers kept | yes: patches only add lines |
| No further restrictions (s6) | yes: no EULA, no click-through |
| Bug reports not sent to Oracle | **fixed today**: java.vendor.url, .url.bug and the VM crash-report URL point at the project |
| Trademark legend, "based on OpenJDK", no Java SE claim | README.md and INSTALL.md (added today) |
| "OpenJDK" in `java -version` | kept as upstream writes it (other builds do the same; the notice allows it for near-identical builds; launchers parse it). Counsel to confirm |
| Runtime release file names the implementor | **fixed today** (`IMPLEMENTOR="Vivace"`) |

## Cadence side
- docs/LICENSING.md section 5 and README: Vivace is a separate program, described in text; never uploaded to Modrinth or
  CurseForge, never in a modpack, no download link in the CurseForge description.
- The Apache-2.0 / GPLv2 incompatibility means no code moves between the two projects in either direction.

## Only the user can do these (before a public Vivace release)
1. Notarization: an Apple Developer ID (paid account) to sign and notarize the .jdk bundles; until then, the INSTALL.md
   quarantine step.
2. A formal trademark clearance search for "Vivace" (software classes 9 and 42; US, EU, UK, WIPO).
3. Read the Minecraft EULA and Usage Guidelines in full (the agent could not fetch them).
4. Ask CurseForge moderators whether a text mention of Vivace's GitHub releases is acceptable in a project description.
5. Optionally, counsel on the open questions above (bindings reading, trademark wording).
6. A public repository for Vivace (the vendor URLs point at the Cadence repository until then: change VENDOR_URL in
   build-tools/build-release.sh).
