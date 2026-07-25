**What this changes**:

**Why**:

**Scope check**: Hyprveil only manages user config under `~/.config` on
Fedora + Hyprland — see the README's "Requirements" section and
[CONTRIBUTING.md](../CONTRIBUTING.md). Does this PR stay within that, or does
it touch system files, another distro, or another compositor?

## Checklist

- [ ] `./tests/run.sh` passes.
- [ ] `./config/hypr/scripts/accent.sh check` passes if a neutral, token, or
      accent-owned template was touched.
- [ ] No generated file was hand-edited — the source (or `.in` template) was
      edited and re-rendered instead.
- [ ] Docs were updated if behavior, defaults, or file locations changed.
