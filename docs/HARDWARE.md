# Hardware profiles

Select a profile after installing configs, or let the full installer prompt once:

```bash
./scripts/06-select-profile.sh
```

Without saved or passed values, form factor and GPU are auto-detected — form
factor from battery presence under `/sys/class/power_supply`, GPU from `lspci`
(a discrete AMD/NVIDIA GPU wins over an integrated Intel one on hybrid laptops)
— and only need a yes/no confirmation. Pass values explicitly to skip detection
or override it:

```bash
./scripts/06-select-profile.sh --form-factor laptop --gpu amd
```

Choices are `desktop` or `laptop`, plus `intel`, `amd`, or `nvidia`. The selection
is saved in `$XDG_STATE_HOME/hyprveil/hardware-profile.conf`; rerunning the full
installer restores that choice without asking or changing it. Passing profile
arguments again is the explicit way to change it.

The generated `~/.config/hypr/profiles/active.conf` sources the chosen templates.
Persistent selection lives outside `~/.config`, so clean managed-config upgrades
cannot erase it.

## Battery and brightness

The Waybar battery helper emits no module when `/sys/class/power_supply` has no
`BAT*` device. Brightness keys call a wrapper that exits successfully when there is
no backlight device or `brightnessctl` is unavailable. Both desktop and laptop
profiles therefore work on machines without either device.

## GPU paths

- Intel: no vendor environment variables.
- AMD: no vendor environment variables.
- NVIDIA: selects the documented NVIDIA path, but still enables no workaround.

No GPU-specific workaround is enabled by default, including after selecting
NVIDIA. The commented examples in `config/hypr/variables.conf` are deliberately
inert. Only enable a variable after confirming a specific problem and the current
driver/upstream recommendation; old blanket recommendations such as always setting
`WLR_DRM_NO_ATOMIC` or `WLR_NO_HARDWARE_CURSORS` can cause new problems.

The optional SDDM installer reads the saved GPU choice. It offers Fedora's X11
greeter package for NVIDIA and the Wayland greeter package for Intel/AMD, while
keeping every system-wide action separately confirmed.
