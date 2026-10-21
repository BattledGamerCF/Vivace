# LEGAL.md: licensing, trademark, distribution and naming research

Date: 2026-10-20
Project: custom OpenJDK 25 build (from jdk25u and/or Azul Zulu sources) for Minecraft on Apple Silicon, distributed alongside the Apache-2.0 "Cadence" mod. The JDK must not be called "Cadence JDK".
Status: research notes for the developer's decision. Not legal advice. Open-source trademark and licence questions should go to a lawyer before any public release.

## Method and limits

- Tools: WebSearch and WebFetch only. Nothing was downloaded or executed.
- Tags:
  - [verified] = primary page or file fetched. Pages were read through a summarising fetch, so re-check exact wording against the source before quoting it.
  - [search] = search excerpt or secondary site only. The primary page was not read.
  - [estimate] = my own knowledge or reasoning, not confirmed in this session.
- Fetch failures that limit this report:
  - oracle.com pages returned HTTP 403 to WebFetch (Third Party Usage Guidelines, Java Branding and Licensing Guidelines PDF). Oracle claims below are [search].
  - minecraft.net EULA and Usage Guidelines timed out on every attempt. Mojang claims are [search] from secondary sites.
  - The OCTLA v4 PDF and the TCK licence PDF returned binary data and could not be parsed.
  - Adoptium's trademark URL returned 404. Modrinth's guessed content-rules URL returned 404.
  - Apple's notarisation page returned only its title. Apple statements are [estimate].
  - CurseForge Mod Author Terms could not be reached.
  - Domain and handle checks: rdap.org returned 403. No domain or GitHub availability was verified.

---

## Part 1: Licensing

### 1. OpenJDK licence (GPLv2 + Classpath Exception, with Assembly Exception)

- The jdk25u LICENSE file is GPLv2 with the Classpath Exception (CE). [verified: github.com/openjdk/jdk25u/blob/master/LICENSE; openjdk.org/legal/gplv2+ce.html]
- The CE applies only to files that Oracle marked with the CE header. [verified: ADDITIONAL_LICENSE_INFO; gplv2+ce summary]
- ASSEMBLY_EXCEPTION lets an executable combine OpenJDK code with "designated exception modules" under GPL2, provided those modules keep their own licences. [verified: github.com/openjdk/jdk25u/blob/master/ASSEMBLY_EXCEPTION]
- ADDITIONAL_LICENSE_INFO says the package bundles independent programs under other licences, for example Apache-2.0 and FreeType, and warns that removing the CE from files may affect redistribution. [verified: github.com/openjdk/jdk25u/blob/master/ADDITIONAL_LICENSE_INFO]

Obligations when redistributing a MODIFIED binary:

- Section 2(a) of GPLv2: modified files must carry prominent notices that they were changed, with dates. [verified: gnu.org/licenses/old-licenses/gpl-2.0.html]
- Section 2(b): a work based on the program must be licensed as a whole under GPL, at no charge to third parties.
- Section 3 (object code), choose one:
  - (a) ship complete machine-readable source with the binary;
  - (b) provide a written offer, valid for at least three years, to supply source for no more than the physical distribution cost;
  - (c) pass along a received offer, which is allowed only for non-commercial distribution. [verified: gnu.org GPLv2 text]
- Offering source from the same download location as the binary counts as distribution of source. [verified: gplv2+ce summary]
- Mere aggregation: an unrelated work placed on the same medium does not come under GPL. [verified: GPLv2 text, final paragraph of section 2]

Can an Apache-2.0 mod and the JDK be distributed together?

- The FSF states that Apache-2.0 is NOT compatible with GPLv2 (it is compatible with GPLv3). [verified: gnu.org/licenses/license-list.html]
- Practical reading [estimate, not legal advice]:
  - OK: the mod as a separate jar or archive, under its own Apache-2.0 licence, loaded by the JDK at run time, and shipped beside the JDK. This matches the CE's purpose (independent modules keep their own licence) and the "mere aggregation" rule.
  - NOT OK: copying Cadence code into the JDK tree, patching JDK or HotSpot files with Apache-2.0 code, or shipping one combined jar or executable. Those would make the combination a GPLv2 work, and Apache-2.0 cannot be combined into GPLv2 code.
  - Keep JDK patches (GPLv2) and mod code (Apache-2.0) in separate repositories and separate artifacts. Ship the Apache-2.0 LICENSE and NOTICE with the mod, and the GPL and third-party notices with the JDK.
- The CE text says linking makes a combined work and then exempts independent modules "regardless of their licence terms". The exact boundary is a known grey area. [estimate]

### 2. Third-party code in the image (legal/ folders)

Components found through GitHub listings of jdk25u (paths relative to src/):

| Location | Files (names verified) | Licence and duties |
|---|---|---|
| java.base/share/legal | aes, c-libutl, cldr, gcc, icu, public_suffix, siphash, unicode, zlib | See rows below |
| java.base/share/legal, zlib.md | zlib | zlib licence. Altered source must be marked as altered. Do not claim authorship of the original. Keep the notice in source distributions. [verified] |
| java.base/share/legal, gcc.md | libgcc and libstdc++ 14.2.0 | GPLv3 with GCC Runtime Library Exception v3.1 (exception text appears later in the file). Relevant to Linux builds. [verified in part] |
| java.base/share/legal, icu.md | ICU | Unicode Licence v3 plus classic ICU Licence for older code. Notice must travel with copies and documentation. Do not use copyright holders' names to promote products. [search: fetched summary of the file; verified] |
| java.base/share/legal, public_suffix.md | Public Suffix List | MPL 2.0. Modified files need source distribution and licence notices must stay. [verified] |
| java.desktop/share/legal, freetype.md | FreeType | Choose FTL or GPLv2 (FTL is not GPLv2-compatible, so the GPLv2 option fits). FTL duties: keep FTL.TXT for source; binary documentation must say the product is based in part on the work of the FreeType Team; no use of names for promotion. [verified] |
| java.desktop/share/legal, jpeg.md | libjpeg (IJG) | IJG licence. Binary documentation must say "based in part on the work of the Independent JPEG Group". Modified versions may be called only "the Independent JPEG Group's software", and IJG names may not be used in advertising. [verified] |
| java.desktop/share/legal, libpng.md | libpng | libpng licence. Altered source must be plainly marked; copyright notice may not be removed or altered; libpng name is not a registered trademark. [verified] |
| java.desktop/share/legal, lcms.md | LittleCMS | MIT. Keep copyright and permission notice. [verified] |
| java.desktop/share/legal, harfbuzz.md | HarfBuzz | "Old MIT". Keep notice and the two disclaimer paragraphs. One file (hb-unicode-emoji-table) is Unicode, Inc. terms. [verified] |
| java.desktop/share/legal, giflib.md | giflib | MIT. Keep notice. [verified] |
| java.desktop/share/legal | colorimaging, mesa3d (Linux) | Names verified; licences not read. |
| java.smartcardio/unix/legal, pcsclite.md | PC/SC Lite headers | BSD 3-clause. Keep the notice in source; reproduce it in binary documentation. [verified] |
| java.desktop/unix/legal | pipewire, xwd | Linux-only. Names verified; licences not read. |
| java.xml/share/legal | bcel, dom, jcup, schema10 parts, xalan, xerces, xhtml10/11, xmlspec, xmlxsd | Names verified. Apache-2.0 is expected for the Apache projects (ADDITIONAL_LICENSE_INFO names Apache-2.0 programs) but these licences were not individually read. [estimate for licences] |
| jdk.internal.le/share/legal | jline | Name verified; licence not read (likely BSD-style). [estimate] |
| java.base/macosx/legal | (not found) | The GitHub path returned 404. The macOS-specific legal list must be taken from a real build output. |

Obligations, summarised: keep the legal/ notices in the image, keep attribution where a licence asks for it, mark modified files where MPL, libpng, zlib or IJG apply, and follow the IJG naming rule if libjpeg is modified. Azul's and BellSoft's notices say some bundled third-party packages carry distribution restrictions and others carry only reporting duties. Azul's notice does not name those packages in the text read. [verified for Azul; search for BellSoft]

### 3. Azul Zulu

- Zulu's OpenJDK-derived parts are under GPLv2 with the Classpath Exception, per Azul's third-party notice for Zulu 21 (April 2026). [verified: docs.azul.com/core/tpls/april-2026/zulu21_jdk_tpl.html]
- Azul offers complete machine-readable source on request for three years from receipt, at cost. [verified: same notice]
- The notice warns that removing the Classpath Exception could compromise further distribution, and recommends legal advice before modifying the package. [verified: same notice]
- Some bundled third-party packages carry distribution restrictions and others only reporting duties. The packages are not named in the text read. [verified: same notice]
- Zulu Community or EULA terms: Azul's legal page links only Terms of Use, Privacy and Compliance. No Zulu Community licence was found. Azul's CCK terms page is dated 2014 and says Zulu extensions are supplied in the Azul Commercial Compatibility Kit. [verified: azul.com/legal/; azul.com/products/core/cck-terms-of-use/]
- Trademarks: Azul states that "Azul Zulu", "Zulu" and the Azul logo are trademarks or registered trademarks. [verified: CCK terms page]
- Redistributing a rebuilt or modified Zulu: no Azul term was found that prohibits it, and none that permits it. The restrictions that matter are the trademark, the third-party packages inside Zulu, and the GPL source duty. [estimate]
- "Based on Azul Zulu" in a name or tagline: no permission was found. Oracle's third-party guidance (see section 4) says accurate "derived from" statements are generally acceptable, but Azul's own policy was not found. [search for Oracle; not found for Azul]
- Other projects that rebuild Zulu: none were found in this session. Open question.
- Practical recommendation: build from upstream jdk25u sources rather than Zulu, which avoids the Zulu mark and any Zulu-specific terms. If Zulu-derived configuration is wanted, get written permission from Azul first.

### 4. Oracle and OpenJDK trademarks

OpenJDK Trademark Notice (version 1.22, dated 2021-10-13 in the fetched copy) [verified: openjdk.org/legal/openjdk-trademark-notice.html]:
- Oracle America owns the OpenJDK name.
- The name may be used in package names and version strings, but only for a substantially complete implementation built from a single official source site, with nearly identical code. Porting work is allowed only in approved OpenJDK projects.
- Copies must carry a trademark legend naming Java and OpenJDK as Oracle trademarks.
- Anything else needs fair use. The notice cites "based on the OpenJDK source code" as an example of fair use.
- Product names are not covered by the grant.
- Implications [estimate]: the product must not be named "OpenJDK ...". A descriptive sentence such as "built from OpenJDK 25 source" is the kind of statement the notice treats as fair use. Include the legend in copies.

Java name:
- Oracle's Java Branding and Licensing Guidelines (December 2024, version 21, per an excerpt) say a written licence is generally needed to use the JAVA name, with narrow exceptions. Product names of the form "X for Java" are allowed for offerings tied to Java. Names beginning with "Java" are not. [search: excerpt of oracle.com/a/ocom/docs/java-licensing-logo-guidelines-1908204.pdf; PDF returned 403]
- Java SE TCK licence agreements say that licensees must follow the current Java Trademark Guidelines, which Oracle may change. [search]
- Conclusion: do not use "Java" anywhere in the product name or tagline.

Third-party-use guidance:
- Oracle's guidance warns against assuming you can use the name of a source code base in the name of a distribution developed from it, and says accurate "derived from" statements are generally acceptable, subject to the upstream licence and any published trademark rules. [search: excerpt of oracle.com/html/3party.html; page returned 403]

"JDK" in a name:
- "JDK" alone was not verified as generic. Liberica JDK and SapMachine JDK both use it [search]. Their trademark standing was not checked.
- Recommendation [estimate]: avoid "Java" and "JDK" in the product name. Use a distinct brand plus a descriptive term such as "runtime".

"Java SE compatible", "certified", "runs Java":
- Passing the TCK is what lets a provider call an implementation "Java" or "Java SE compliant". Compliance is all or nothing. [verified: Azul TCK blog summary, azul.com/blog/use-tck-testing-to-ensure-that-your-java-distribution-conforms-to-the-java-se-specification/]
- Without a TCK pass, do not claim compatible, certified, or Java SE compliant. A plain descriptive phrase such as "runs Java programs" is probably acceptable but was not verified. [estimate]

What other distributions say:
- Temurin: Eclipse says Oracle owns the "Java" and "OpenJDK" trademarks, and that distributing OpenJDK builds requires compliance with additional Oracle terms, pointed to in the Adoptium charter. [verified: projects.eclipse.org/node/20940] Temurin's name belongs to the Eclipse Foundation [search: notice files]. Working-group minutes show that whether third-party builds may use the Temurin mark was still open [search].
- Corretto: GPLv2 with CPE. Its FAQ says Corretto is TCK-certified. The FAQ says nothing about trademark use of "Corretto" or "Java". [verified: aws.amazon.com/corretto/faqs/]
- Liberica (BellSoft): "Liberica" and "BellSoft" are BellSoft trademarks [search: licence notices]. BellSoft says all Liberica JDK binaries are TCK-verified; this is a self-claim [search: BellSoft JCP statement].
- SapMachine (SAP): a downstream fork under the same licensing as OpenJDK. Naming and trademark policy not addressed [search: github.com/SAP/SapMachine].
- JetBrains Runtime (JBR): GPL-2.0 with Classpath Exception per JetBrains' third-party page [search]. An old JetBrains forum reply said they could not call the runtime "Java" [search; informal, dated].
- Pattern: every distribution found uses its own brand and does not start a name with "Java".

### 5. TCK and JCK

- Not required to distribute an OpenJDK build. The OpenJDK licence does not impose it. [estimate; no OpenJDK legal page mentions a TCK requirement]
- Required before claiming Java or Java SE compatibility (see section 4).
- OCTLA (OpenJDK Community TCK Licence Agreement): the JCK is available at no charge to developers planning a compatible implementation based on OpenJDK-derived code, or taking part in OpenJDK work. The requesting project must be active, the requester must sign the OCTLA and the Oracle Contributor Agreement, and the request goes through a screening committee. [verified: openjdk.org/groups/conformance/JckAccess/]
- Builds tested under the OCTLA must be distributed only under the GPL of OpenJDK. [verified: inside.java/2018/10/15/octla/ summary; Azul TCK blog]
- The TCK licence is internal-use only; licensees may not sub-licence or distribute it to third parties. [search: TCK licence excerpts]
- Independent implementations are excluded from the OCTLA and directed to Oracle's commercial JCK options. [verified: inside.java summary]
- Implication: a TCK claim is possible only if the project takes OCTLA access and distributes the TCK-tested build under GPL. The OCTLA text itself could not be read here, so the terms for a game-focused build need a lawyer's reading.

### 6. Distribution channels

Modrinth:
- Content rules and terms, as read: no rule against bundled executables or JDKs was found. No open-source requirement was found. Prohibited: malware, impersonation, implied endorsement, trademark infringement. Project titles should be only the project name. [verified: modrinth.com/legal/rules; modrinth.com/legal/terms]
- The rules page for executables and launchers was not reached.
- Recommendation: do not put a JDK inside the mod file. Ask Modrinth moderation before uploading any runtime archive.

CurseForge:
- Website rules read: no rule on executables or bundled JREs was found. Moderation is best-effort. Off-site links must sit at the bottom of the page. [verified: support.curseforge.com/support/solutions/articles/9000197998]
- Mod Author Terms (where executable rules would sit) were not reached. Open.

GitHub Releases:
- Each release file must be under 2 GiB. A release can hold up to 1000 assets. There is no limit on total release size or bandwidth. [verified: docs.github.com about-releases]
- A macOS JDK archive is likely around 200 MB [estimate], so GitHub Releases can host it. The JDK should be a separate download, not part of the mod.

Mojang (Minecraft EULA and Usage Guidelines):
- Not read directly (timeouts). Secondary sources say: free mods are allowed; mods built from Mojang code or assets may not be sold unless Mojang authorises it; mods must not contain substantial Mojang code; Mojang may revoke permissions at its discretion. [search: conductatlas.com; esports.net; a modding site]
- A secondary, unverified source says mods should not be shipped inside pre-installed modded copies of the client. [search]
- Recommendation: keep the JDK separate from the mod. Do not use the Minecraft logo or name in the JDK's name. Check the Mojang terms directly before launch, and ask Mojang about a bundled runtime or any launcher-style package.

### 7. macOS distribution

- Apple's Developer ID route requires a paid Apple Developer Program membership, signing with a Developer ID certificate, notarisation, the hardened runtime, and a secure timestamp. [estimate; Apple page returned only its title]
- Browser downloads carry the com.apple.quarantine attribute. Unsigned, un-notarised apps are blocked or warned, and recent macOS versions removed the simple Control-click override in favour of System Settings. [estimate; search for quarantine behaviour]
- Ad-hoc signing (codesign with "-") does not satisfy Gatekeeper for downloaded software. Users would need to remove quarantine (xattr -d com.apple.quarantine) or approve the app manually. Third-party guides describe this workaround. [search; estimate]
- A JDK contains many Mach-O binaries and dylibs. Each must be signed with the hardened runtime, and the JVM needs JIT-related entitlements (for example com.apple.security.cs.allow-jit). The notarised wrapper (zip, dmg or pkg) must also be submitted. [estimate]
- Whether Temurin, Zulu, Corretto or Liberica notarise their macOS builds was not checked. Open.

### 8. Windows and Linux

Windows, if built with MSVC:
- Distribution of the Visual C++ runtime is limited to licensed Visual Studio users and is subject to the Microsoft Software License Terms. Only files on the REDIST list may be redistributed. The usual route is the vc_redist installer. [verified: learn.microsoft.com/en-us/cpp/build/redistributing-visual-cpp-files]
- Check the current VS licence terms before shipping the runtime DLLs with the JDK. [estimate]

Linux:
- The GCC runtime (libgcc, libstdc++) is covered by the GCC Runtime Library Exception, so the runtime may be redistributed with the exception's terms. [verified in part: java.base/share/legal/gcc.md]
- Other Linux components (mesa3d, pipewire, xwd, pcsc-lite) carry BSD, MIT or X-style licences. Their notices must travel with the build. [verified for pcsc-lite; others not read]

---

## Part 2: Names

### 9. Existing JDK and JVM names to avoid

Verified in this session:
- Java and OpenJDK (Oracle trademarks). Temurin (Eclipse Foundation). Azul Zulu and Zulu (Azul, registered). Corretto (Amazon). Liberica (BellSoft). SapMachine (SAP). JetBrains Runtime / JBR (JetBrains).
- Presto (PrestoDB, Java SQL engine). Apache Geode (Java data-management product). CadenzaFlow (Java BPM engine). Viva (SourceForge Java runtime collection). Kaffe (GPL clean-room JVM). OpenJ9 (Eclipse JVM) and its "metronome" GC policy [estimate for the GC policy].

Known from my own knowledge, not checked this session [estimate]:
- Microsoft Build of OpenJDK, Semeru (IBM), Dragonwell (Alibaba), GraalVM (Oracle), Mandrel (Red Hat), Kona (Tencent), Bisheng (Huawei), Trava, Red Hat build of OpenJDK, OpenLogic (Perforce), Zing and Zulu Prime (Azul), ojdkbuild, Shipilev builds, Oracle JDK, HotSpot.
- "Cadence JDK" (already taken, per the brief).

### 10. Candidate names and conflict checks

Method: one web search per name in the form "<Name> software product trademark github project". Results for "JDK JVM" queries were too noisy, so plain product queries were used. Coverage is thin for rare words. Minecraft-mod checks were run only where a hit appeared (Basalt). "No conflict found" does not mean cleared; a USPTO, EUIPO and GitHub search is still needed.

| # | Name | Result | Tag |
|---|---|---|---|
| 1 | Tempo | No tempo-software hit (search returned noise). Known conflicts: Tempo (Jira time-tracking add-on) and Grafana Tempo (tracing backend). CONFLICT (dev tools). | [estimate] |
| 2 | Allegro | Allegro game library (liballegro) referenced in a Fedora review. Allegro e-commerce brand exists. CONFLICT (game dev). | [search] / [estimate] |
| 3 | Metronome | metronome-java SDK on Maven Central (com.metronome.api); DavesMetronome Java app; J9/OpenJ9 "metronome" real-time GC policy. CONFLICT (JVM-adjacent). | [search] / [estimate] |
| 4 | Downbeat | No software hit. "Down JDK" is a blog title only. DownBeat is a known music magazine. Minor (music publishing). | [search] / [estimate] |
| 5 | Vivace | No software hit. Niche "Viva" Java runtime on SourceForge; an unnamed tiny C++ JVM. NONE FOUND (minor niche overlap). | [search] |
| 6 | Presto | PrestoDB, a Java SQL engine with many forks. CONFLICT (Java data tooling). | [search] |
| 7 | Fermata | AndreyPavlenko/Fermata on GitHub, Java-primary, about 1.0k stars. Purpose believed to be an Android UPnP app. CONFLICT (GitHub name). | [search] / [estimate] |
| 8 | Coda | No search hit. Coda (coda.io docs SaaS) and the Coda text editor. CONFLICT (productivity software). | [estimate] |
| 9 | Andante | No software hit. Closest: ANTEA (asset-integrity software, near-miss). NONE FOUND. | [search] |
| 10 | Staccato | Staccato AI (music-creation software, US and Canada filings 2024-25); Hamilton Thorne STACCATO (Class 9, lab software); FRONTLINE Selling STACCATO (SaaS). CONFLICT. | [search] |
| 11 | Legato | LEGATO NETWORKER (Legato Systems, now EMC); Sierra Wireless Legato framework on GitHub (MPL-2.0); Legato Intelligence filing (2023). CONFLICT. | [search] |
| 12 | Crescendo | Crescendo Interactive trademarks (computer programs since 1984); Crescendo music notation (Steam); Adelyte Crescendo (Crestron framework on GitHub). CONFLICT. | [search] |
| 13 | Overture | Overture Maps Foundation (Linux Foundation, GitHub OvertureMaps). CONFLICT (open-data software). | [search] |
| 14 | Prelude | Prelude SIEM (security tool, GPLv2); Prelude Systems, Software and Products trademarks; Emacs Prelude on GitHub. CONFLICT. | [search] |
| 15 | Rubato | Rubato Composer (GPL music tool); rubato Rust audio-resampling crate; rubato PyPI package. CONFLICT (audio dev). | [search] |
| 16 | Cadenza | CadenzaFlow BPM (Java, Apache-2.0); CADENZA trademark (VoiceLine, 1990, multimedia software); UK Cadenza hearing-aid ML project. CONFLICT (Java product). | [search] |
| 17 | Ostinato | Ostinato open-source packet generator [estimate]; Gumroad "Ostinato Classic" (commercial); OSTINATO trademark (VR software, Danz Cai). CONFLICT (software). | [search] |
| 18 | Adagio | Adagio build tool (make-like); hgascon/adagio static analyser; mosteo/adagio (Ada Gnutella2); adagios (Nagios configuration). CONFLICT (several dev tools). | [search] |
| 19 | Largo | Largo Technology Group fitness-software filings; Project Largo (INN WordPress framework on GitHub, 2012). Minor. | [search] |
| 20 | Arpeggio | Arpeggio Software KIDSING (1992); arpeggio chord web app on GitHub; arpeggiata modular engine; Arpeggio hardware (Tangible Instruments); Reason Arpeggio Lab. CONFLICT (music). | [search] |
| 21 | Basalt | Basalt Lua UI framework for CC:Tweaked (a Minecraft mod ecosystem); VladyslavUsenko/basalt (C++ VIO library, about 866 stars); basalt-rs; bash-bastion/basalt (package manager). CONFLICT (dev tools; Minecraft-adjacent). | [search] |
| 22 | Fjord | FJORD federal word mark (Reg. 5098945, software-design services); jhtjernsmo/fjord (GitHub, 2026); Fjord F# JVM implementation; Fjord hosted Forgejo (2026). CONFLICT. | [search] |
| 23 | Cairn | cairn-dev/cairn (AI coding agent); tanlnm512/cairn (pip cairn-intel); CairnOpen energy simulator; quentinzhang/cairn (macOS app); no software trademark for "Cairn" found. CROWDED GitHub namespace (moderate). | [search] |
| 24 | Geode | Apache Geode (a Java data-management product, "Apache Geode" mark); geode-sdk (Geometry Dash mod framework); Geode Solutions (geometry viewer); devnote-dev/geode (Crystal). CONFLICT (Java product). | [search] |
| 25 | Moraine | No software or GitHub hit. "Moraj Lab" is a near-miss only. NONE FOUND. | [search] |
| 26 | Ember | Ember.js (JavaScript framework); Tilde Inc. holds US registrations for Ember name and logo. CONFLICT. | [search] |
| 27 | Kiln | Kiln AI (Chesterfield Laboratories, dev workbench); Fog Creek KILN (source-control software, Class 9); Canva KILN (data-visualisation application); cougz/kiln (CadQuery tool). CONFLICT. | [search] |
| 28 | Tarn | Tarn Software Inc. mark BYTE INTO THE MARKET (1997, securities software); npm "tarn" resource pool (very widely used). Minor (npm name taken). | [search] |
| 29 | Tenuto | No software or GitHub hit. Musical notation term. NONE FOUND. | [search] |
| 30 | Cantabile | Cantabile live-performance music host (Topten Software, commercial, with a rebranding kit). CONFLICT (music software). | [search] |
| 31 | Ritornello | No hit. Search thin for a rare word. NONE FOUND (weak). | [search] |
| 32 | Drumlin | No hit. Search thin. NONE FOUND (weak). | [search] |
| 33 | Esker | ESKER word mark (Reg. 2600175, Class 9 software) owned by SA ESKER; Esker enterprise software. CONFLICT. | [search] |

Gaps: Minecraft-mod and launcher checks were not run for most names. Only Basalt (CC:Tweaked) surfaced one.

### 11. Shortlist (no conflicts found in search; not cleared)

1. Vivace: Italian tempo marking meaning "lively". Short and pronounceable. No software hit. Faint overlap with the niche "Viva" runtime.
2. Moraine: geology term for a glacial debris ridge. Fits a nature-and-geology family. No software or GitHub hit.
3. Tenuto: musical notation term for a held note. Pairs with Cadence. No software hit.
4. Downbeat: rhythm term. No software hit. DownBeat is a known music magazine, a publishing mark rather than a dev-tool one. [estimate]
5. Andante: walking-pace tempo. No software hit. Common word, so weaker distinctiveness.
6. Drumlin: geology term for a glacial hill. No hit, but the search was thin.
7. Ritornello: musical refrain. No hit, but the search was thin. Long (four syllables).

Domains and handles: not checked. Both rdap.org and the GitHub checks were blocked or not run, so availability is unknown for all seven.

---

## Answers

1. GPLv2+CE: a modified binary must ship full source or a three-year cost-limited written offer, mark changed files with dates, and keep notices. Apache-2.0 mod: fine as a separate artifact that loads on the JDK; never merged into JDK source, because the FSF says Apache-2.0 is incompatible with GPLv2.
2. Third-party code: about 34 legal files (listed by module in section 2), each with notice duties. Watch the IJG naming rule, the FreeType binary credit line, the MPL-2.0 source duty for public_suffix, and the libpng and zlib altered-source marking.
3. Azul: Zulu's OpenJDK parts are GPLv2+CE with a three-year source offer. "Zulu" is a registered Azul trademark, so do not use it in the name. No Zulu redistribution term was found; build from upstream jdk25u or get Azul's written permission.
4. Oracle: "OpenJDK" may appear only as a package or version string for near-identical builds. "Based on OpenJDK source" is a fair-use style statement. "Java" must not be in the name. "X for Java" is an Oracle-permitted form under its guidelines [search]. "Java SE compatible" requires a TCK pass.
5. TCK: not required to distribute. Required before any Java SE compatibility claim. OCTLA gives free access for OpenJDK-based builds, but those must be distributed under GPL.
6. Channels: Modrinth and CurseForge rules read do not bar a bundled runtime, but the executable-specific rules were not reached, so ask moderation before uploading a JDK. GitHub Releases allows 2 GiB per file, 1000 assets, no total cap. Mojang terms were not read; keep the JDK separate from the mod.
7. macOS: a Developer ID certificate and notarisation (paid Apple Developer Program) are needed for smooth Gatekeeper behaviour. Ad-hoc signing forces users to remove quarantine or approve manually. Estimate only; Apple's page was not read.
8. Windows and Linux: VC++ runtime redistribution is governed by Microsoft's licence and the REDIST list. The Linux GCC runtime carries the GCC Runtime Library Exception.
9. Names to avoid: see section 9. Verified in session: Temurin, Zulu, Corretto, Liberica, SapMachine, JBR, Presto, Apache Geode, CadenzaFlow.
10. Names checked: 33. No conflict found (search, not cleared): 7. Minor overlap only: 2 (Largo, Tarn). Conflict found: 24, including Esker (a registered Class 9 software mark).
11. Shortlist: Vivace, Moraine, Tenuto, Downbeat, Andante, Drumlin, Ritornello.

---

## Open questions

1. Oracle pages (Third Party Usage Guidelines, Java Branding PDF, TCK licence) returned 403. Need a direct read, or a written answer from Oracle about "JDK" in names, "runs Java", and "X JDK".
2. Mojang EULA and Usage Guidelines: read directly. Specifically: is a Fabric mod shipped alongside a bundled JDK allowed, and would a JDK-plus-mod bundle count as a modified client or launcher?
3. CurseForge Mod Author Terms: executables and bundled runtimes.
4. Modrinth content rules: executable and launcher rules.
5. Azul: Zulu Community terms; permission to derive from Zulu; how other projects that rebuild Zulu handle naming.
6. OCTLA v4 text (PDF unreadable here): check whether a Minecraft-targeted build qualifies and what it says about trademarks.
7. Apple's notarisation documentation (only the title was read); JIT entitlements for a JVM; how Temurin, Zulu, Corretto and Liberica notarise macOS builds.
8. Trademark clearance: USPTO, EUIPO and TMview searches for the shortlist names, plus GitHub org and user names, Modrinth and CurseForge project names, and domains (rdap.org was blocked).
9. Temurin: did Adoptium resolve the third-party-build question (the working-group vote was postponed)?
10. macOS legal/ folder list: take it from a real build output, since the macosx/legal path was not found.
11. GPL and Apache-2.0 boundary: a lawyer's read on whether a mod loaded through the JDK's module path counts as an independent module under the CE.
12. Whether the project name or tagline may mention "Minecraft" (Mojang trademark). Assumed no.
