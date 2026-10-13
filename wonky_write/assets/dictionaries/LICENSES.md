# Spellcheck dictionaries: sources and licenses

Hunspell dictionaries used by the Wonky Write spell checker
(`package:wonky_write_core/spellcheck.dart`, Write 04 §28.2). Each `<tag>.aff` +
`<tag>.dic` pair is an unmodified copy of the upstream files (all upstream files are
already UTF-8 with `SET UTF-8`, so no conversion was needed). `index.json` lists them for
the app. The full license text of each dictionary is in `LICENSE-<tag>.txt` (the upstream
license file, followed by the full text of the chosen license where the upstream file only
refers to it).

All files were taken from the npm packages by Titus Wormer (wooorm/dictionaries,
<https://github.com/wooorm/dictionaries>), downloaded from jsDelivr
(`https://cdn.jsdelivr.net/npm/<package>@<version>/index.aff|index.dic|license`) on
2026-10-13.

| Tag | Name | npm package | Upstream source and authors | License used | Size (.aff + .dic) |
|-----|------|-------------|-----------------------------|--------------|--------------------|
| `en-US` | English (US) | `dictionary-en@4.0.0` | SCOWL / wordlist.sourceforge.net, en_US Hunspell dictionary version 2020.12.07, Kevin Atkinson and contributors | MIT AND BSD (SCOWL license, see file) | 0.55 MB |
| `en-GB` | English (UK) | `dictionary-en-gb@3.0.0` | SCOWL / wordlist.sourceforge.net, en_GB-ise Hunspell dictionary version 2020.12.07, Kevin Atkinson, Marco A.G. Pinto and contributors | MIT AND BSD (SCOWL license, see file) | 0.56 MB |
| `fr-FR` | Français (France) | `dictionary-fr@3.0.0` | Dictionnaires orthographiques français 7.5 ("classique"), Olivier R., Grammalecte (<https://grammalecte.net/>) | MPL-2.0 | 1.43 MB |
| `es-ES` | Español (España) | `dictionary-es@4.0.0` | RLA-ES, Diccionario para corrección ortográfica en español 2.8 (es_ES), Santiago Bosio and contributors | Tri-licensed GPL-3.0-or-later OR LGPL-3.0-or-later OR MPL-1.1-or-later; used under **LGPL-3.0-or-later** (or MPL-1.1), not GPL | 0.87 MB |
| `nl-NL` | Nederlands | `dictionary-nl@2.0.0` | OpenTaal (<https://opentaal.org>), Simon Brouwer, Sander van Geloven, Ruud Baars | Dual-licensed BSD-3-Clause OR CC-BY-3.0; used under **BSD-3-Clause** | 2.54 MB |
| `sv-SE` | Svenska | `dictionary-sv@4.0.0` | Swedish dictionary for spell checking, Göran Andersson | LGPL-3.0 | 2.36 MB |
| `da-DK` | Dansk | `dictionary-da@6.0.0` | Stavekontrolden 2.8.034 (<http://www.stavekontrolden.dk>), Foreningen for frit tilgængelige sprogværktøjer, based on data from Det Danske Sprog- og Litteraturselskab | Tri-licensed GPL-2.0 OR LGPL-2.1 OR MPL-1.1; used under **LGPL-2.1** (or MPL-1.1), not GPL | 3.80 MB |

## Not shipped

Candidates that were checked and left out:

| Language | npm package | Reason |
|----------|-------------|--------|
| pt-BR | `dictionary-pt@4.0.0` (LGPL-3.0 OR MPL-2.0) | 5.4 MB combined, above the ~4 MB size limit |
| pl-PL | `dictionary-pl@2.0.0` (GPL-3.0 OR LGPL-3.0 OR MPL-2.0) | 4.9 MB combined, above the ~4 MB size limit |
| de-DE | `dictionary-de@3.0.0` (GPL-2.0 OR GPL-3.0) | GPL-only |
| it-IT | `dictionary-it@2.0.0` (GPL-3.0) | GPL-only |
| nb-NO | `dictionary-nb@3.0.0` (GPL-2.0) | GPL-only |

## Obligations

- **MIT / BSD (en-US, en-GB, nl-NL)**: keep the copyright notices and license texts
  (`LICENSE-<tag>.txt`) with the files and list them in the app's About / licenses page.
- **MPL-2.0 (fr-FR)**: the dictionary files stay under the MPL; ship them unmodified (or
  publish modifications of these files under the MPL) and keep `LICENSE-fr-FR.txt`.
- **LGPL-3.0 / LGPL-2.1 (es-ES, sv-SE, da-DK)**: the dictionaries are data loaded at run time and can be
  replaced by the user; ship them unmodified with their license text and say where the
  source is (above). Modifications of these files must stay under the LGPL.
