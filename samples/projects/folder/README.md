# TFolder sample (Windows: target of Lote B)

A three-tab form using the FiveWin-style `FOLDER ... PROMPTS` syntax:

```harbour
@ 12, 12 FOLDER ::oFolder1 OF Self SIZE 444, 290 ;
         PROMPTS "&General", "&Database", "&About"

@ 16, 16 SAY ::oLabelName PROMPT "Your name:" ;
         OF ::oFolder1:aPages[1] SIZE 180, 22
```

Each tab maps to a `TFolderPage` panel (`oFolder:aPages[N]`); controls
dropped on a page are owned by that page and shown / hidden when the
user clicks the tab.

## Status

| Backend  | Status                                                    |
|----------|-----------------------------------------------------------|
| macOS    | Working (commit `f056bf3` - TFolder + TFolderPage)        |
| Windows  | **Not yet** - this sample is the validation target for the in-progress Lote B port |
| Linux    | Pending after Windows                                     |

## What we expect once the port lands

1. Open `Project1.hbp` in the IDE.
2. The form designer shows a TFolder with three named tabs.
3. Click each tab in the designer; the corresponding controls appear.
4. Run > Run. Native Win32 SysTabControl32 with three pages, each
   with the right widgets, the Connect button on page 2 updates its
   label.

## Why this sample exists now

So that the code-generator round-trip can be tested as soon as the
Win32 TFolder backend is wired in. Drop-in target for the work in
progress; once everything compiles and runs, the sample lives on as
the canonical TFolder example for users.
