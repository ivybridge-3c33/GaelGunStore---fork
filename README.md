# GaelGunStore-Firearms — B42 Bug-Fix Fork

A private **Build 42** bug-fix fork of **GaelGunStore-Firearms** (original by
Pen-Pen Pirulin), maintained for a co-op server. **Not for redistribution.**

> **Interim use only.** This fork only applies B42 bug fixes and is a stopgap
> until the official mod is updated for B42. Please switch back to the official
> mod once that happens.

## Credits
- Original mod, all weapons, models and assets: **Pen-Pen Pirulin**
- Framework: **AWCWF** (Advanced Warfare Community Weapons FrameWork) — required, subscribe separately
- B42 fixes: this fork

## Requirements
- Project Zomboid **Build 42** (42.17+)
- **AWCWF** framework mod

## What this fork fixes

### v1.3 (latest)
- Attachment positions on sawn-off **Browning Auto-5**, **Becker**, **MTS-255** (were floating off the gun)
- **Remington Model 8**: grip / scope / bipod positions
- **Remington 121**: scope position
- **Remington 870** sawn-off can now mount a buttstock
- **QBS-09**: buttstock slot removed
- Suppressor/choke blocked on more sawn-off shotguns
- **AAC Honey Badger** foregrip + **LVOA** bipod positions
- **HKG28** bipod position
- **ENARM Pentagun** & **Jackhammer**: proper Auto/Single fire mode (were single-only and fired an uncontrolled full-auto when fully kitted)

### v1.2
- Attachment & magazine models not showing on weapons (part-render crash)
- "Single" fire mode firing full-auto / faster than Auto
- JS-2000 / Ithaca M37 sawn-off: no model + could not fire
- More grenades & gun tools showing as "Base.xxx"
- Inspect / attach UI crash when playing without `-debug`
- M1887 attachment positions

### Earlier (pre-1.2)
- Reload "surrender" animation / base-pose bugs
- Lever-action rifles use the vanilla lever-action reload
- Crash-to-menu when firing .357 guns on 42.19
- Attachment removal fixes (incl. broken-screwdriver vanilla bug)
- Item names showing as `Base.xxx`, magazine rendering, MK18 fire pose

See [`mods/GaelGunStore/CHANGELOG.txt`](mods/GaelGunStore/CHANGELOG.txt) for the full, detailed changelog.

---
All original content belongs to its respective authors.
