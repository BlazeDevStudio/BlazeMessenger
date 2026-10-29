# Windows incoming video-call crash: field evidence protocol

Development-only diagnostic procedure. **No user data, call content, or crash dumps are required.** The reported Windows minimized/tray incoming video Answer crash is not resolved or certified by an emulator run.

## Reproduce on an authorized PC and phone

1. Note the exact **source commit and Windows package hash**, without copying personal filenames, device IDs, IP addresses, or conversation identifiers. Use a disposable/test identity and an otherwise idle, trusted private LAN.
2. Start LAN Messenger on Windows and the Android peer. Minimize Windows to its tray, initiate an Android **video** call, then press the Windows native **Answer** popup. Repeat once after opening Windows normally as a positive-control comparison. Record only whether the Windows process terminates, whether video frames appear, and the relative stage (ringing, Answer, video attach, compact restore).
3. Immediately on Windows run this from the application source directory in PowerShell:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\windows_crash_report.ps1 -LookbackMinutes 20
   ```

   The script reads only local Windows Application Error **1000** and Windows Error Reporting **1001** events for `lan_messenger.exe`. Its default output is a local temporary `LAN-Messenger-Windows-Crash-Report.json` file. It does not upload anything or write registry keys.
4. Review the JSON **before sharing**: `FaultingModule`, `ExceptionCode`, `FaultOffset`, `AtUtc`, `EventId`, `MatchedEvents` and `EventLogReadErrorType` are the intended fields. The module name is stripped of path components; exception and offset fields must be hexadecimal. Do not share full Event Viewer messages, logcat, device addresses, PC usernames, phone numbers, tokens, local documents or memory dumps.
5. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\windows_crash_report.ps1 -SelfTest` to verify the collector's synthetic Application Error and WER parsers. **A clean report means no matching event was found in that time range, not proof that no crash happened.** Check Windows Reliability Monitor separately if events are unavailable.

## Acceptance conditions

- Windows minimized, maximized, restored, and close-to-tray Answer/Decline all complete with no process exit.
- On a connected call, Windows video rendering and Android remote video frames both persist through compact-window transitions; no stale popup remains after hangup.
- On forced Windows process termination, the surviving Android device ends its orphaned call within the configured bounded reconnect grace period and restores its controls.
- Repeat on real Windows + Android devices using the signed/hashed same-source candidate. **CI unit tests, hosted Windows minimize smoke and two-Android emulator calls do not satisfy this physical gate.**
