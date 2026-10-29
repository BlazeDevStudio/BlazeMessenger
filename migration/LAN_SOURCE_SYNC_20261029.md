# LAN Messenger isolated source synchronization — October 29, 2026

**Development-only draft: no release, merge, or deletion authorized.**

- Destination: `BlazeDevStudio/BlazeMessenger`, only `apps/LAN-Messenger/` plus this provenance note and LAN-only CI workflow.
- Previous dedicated migration: `migration/connectit-lan-source-20261029` at `1a6729f49d6ebad31af66b23a7c6a8fd6b284f7a`. It imported LAN Messenger from `BlazeDevStudio/BlazingSystems-Experiments` legacy PR #235 commit `e115889f8a5ff8b50f9fc0c48afbb6fa24340bfe`.
- Current LAN-only source: `BlazeDevStudio/BlazingSystems-Experiments` draft PR #253, exact commit `4460c76d30652fb3e7a5bb707b9cdef3b6fd7220`, stacked over PRs #244, #245, #249, #250, #251. The [six-job CI run](https://github.com/BlazeDevStudio/BlazingSystems-Experiments/actions/runs/40888999138) completed successfully, including two-emulator discovery/voice, video/PiP, and peer death. This is cloud automated evidence only.
- Scope: the thirteen LAN source files modified or added between the exact legacy source and PR #253 have been copied as full UTF-8 content. No ConnectIT files, production signing keys, user data, or binaries were copied or modified.
- Build verification: `.github/workflows/lan-messenger-sync.yml` is dedicated to the new `apps/LAN-Messenger` path and separately compiles/analyzes/tests Android and Windows. Two-emulator end-to-end evidence belongs to the exact Experiments commit above; this new workflow does not claim a physical cross-platform acceptance.
- Git history stays intact in Experiments. All separate ConnectIT development, `ConnectIT/` migrations and PRs remain owned by their respective developer. Do not rewrite that history.
- **NO-GO**: requires physical Windows minimized incoming Android video Answer/Decline, video media playback and native fault report, Windows-process-death peer recovery on Android, signing continuity, and the existing release acceptance checklist.
