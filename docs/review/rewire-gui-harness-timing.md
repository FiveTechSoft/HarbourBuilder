# Run GUI harness: timing limits

The rewire Run GUI scripts currently wait at most 40 seconds for
`/tmp/debugmodules-result.txt` after requesting Run:

- `tests/test_rewire_manual_green_gui.sh`
- `tests/test_rewire_convention_gui.sh`
- `tests/test_rewire_inactive_gui.sh`
- historical RED: `tests/test_rewire_manual_red_gui.sh`

They remove the old sentinel before Run and require `MODULES-EXECUTED` before
checking the real GTK button click and startup sentinels. The fixed deadline
is a harness limit, not a product build deadline. A missing sentinel at 40
seconds does not distinguish a slow compilation from a compiler or Run error.

Independent review reported cold builds taking 60-90 seconds on one vCPU.
Such a run needs a longer observation window before making a product judgment.
Keep the reviewed source and binary unchanged when repeating that check.
Record the actual wait, compiler output, assembled file, application window,
and click/startup sentinels separately. Do not label a timeout as a product
failure, or accept a later sentinel as evidence of the earlier attempt without
checking process and fixture identity.

## Future harness-only improvement

Use a configurable bounded build wait, with a default that accommodates cold
single-vCPU builds. Poll the expected fresh sentinel while retaining compiler
and IDE diagnostics, and distinguish timeout from explicit compile/link errors.
After startup, continue to require an actual application button click and its
own fresh sentinel. Report the script exit and outer cleanup exit separately.
Do not change product timeouts or event-generation code for this harness issue.

This note changes no scripts or product code. The current audit remains open
until its runtime and refusal/recovery checks finish.
