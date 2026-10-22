# Contributing

## Layout

| File | Responsibility |
| --- | --- |
| `codesnap.scm` | Public commands, settings state, capture orchestration, setup check |
| `codesnap-menu.scm` | The interactive menus and pickers |
| `codesnap-picker.scm` | Single-list picker, a deliberate fork of the [ui-utils.hx](https://github.com/waddie/ui-utils.hx) picker. It keeps rows stationary until the highlight reaches a visible edge, which upstream does not do. |
| `codesnap-compat.scm` | The only module that calls Helix editor APIs. If the Steel branch changes one, fix it here. |
| `codesnap-core.scm` | Pure logic: validation, Silicon arguments, text handling, settings file format |
| `codesnap-process.scm` | Subprocesses, temporary files, atomic publication |
| `codesnap-config.scm` | Reading and writing `codesnap.toml` |
| `scripts/` | `check-helix-api.sh` and `helix-api.txt`, the list of Helix API names the plugin depends on |

Add any new Helix API name you use to `scripts/helix-api.txt`.

## Automated checks

Needs Steel and a POSIX shell; Silicon and a clipboard are not required.

```bash
steel tests/codesnap-core-test.scm
mkdir -p .test-work/tmp
PATH="$PWD/tests/fixtures:$PATH" \
TMPDIR="$PWD/.test-work/tmp" \
SILICON_CONFIG_PATH="$PWD/tests/fixtures/silicon-config" \
steel tests/codesnap-process-test.scm
```

Check that every Helix API name still exists upstream (CI runs this weekly):

```bash
git clone --depth 1 -b steel-event-system https://github.com/mattwparas/helix /tmp/helix-steel
scripts/check-helix-api.sh /tmp/helix-steel
```

## Smoke test in a real Helix

Needs `hx` built with Steel, `silicon`, and the ui-utils.hx cog installed. It uses a throwaway configuration and never touches yours.

```bash
python3 tests/helix/smoke.py
```

It checks the setup report, a real capture to a PNG, saving settings from the menu, and recovery from a bad settings file.

## Manual checklist

Run these in a real Helix before a release. Keep test images in the ignored `.test-work/` directory.

1. Select a line and save through the file picker; cancel an overwrite prompt and confirm the file is untouched.
2. Search the theme and font pickers; the highlight and scroll position must reset to the first match when the text changes.
3. In a short terminal (about 70 by 18), open `:codesnap-menu`. Row positions must stay fixed while moving, including when wrapping. In Settings, move past the last visible row and reverse: the list scrolls only at a visible edge.
4. Export a configuration, paste it into `helix.scm`, restart, and confirm the values apply.

`tests/helix/` also contains an isolated configuration with test-only commands (`:codesnap-check-start`, `:codesnap-check-finish`, `:codesnap-check-menu`) for assertions inside a running editor. Launch it with `HELIX_STEEL_CONFIG="$PWD/tests/helix" hx --config tests/helix/config.toml tests/codesnap-core-test.scm`.

## Releasing

1. Move the changelog's unreleased entries under a new version heading.
2. Update `version` in `cog.scm`.
3. Run the automated checks and the smoke test.
4. Tag the release (`git tag v0.x.y`) so users can pin it.
