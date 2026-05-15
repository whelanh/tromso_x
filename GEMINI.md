# Gemini Project Mandates

## Build and Diagnostics
- **ALWAYS** use the `Justfile` for running `bst` (BuildStream) and diagnostic commands.
- The `Justfile` wraps BuildStream inside a specific container (`bst2`) with correct volume mounts and permissions.
- **Example Usage:**
  - `just bst build oci/tromso.bst`
  - `just bst show oci/tromso.bst`
  - `just bst shell oci/tromso.bst`
- Avoid running `bst` directly on the host or via `pipx` unless explicitly instructed, as the containerized environment is the source of truth for reproducibility.

## VM & Graphical Boot Mandates

### Systemd Configuration
- **Break Cycles**: Core services like `dbus.service` must **not** have `Before=basic.target` to avoid ordering cycles that lead to emergency shells.
- **Enable GUI**: SDDM must be explicitly enabled in `elements/tromso/system-config.bst` (as `display-manager.service` and in `graphical.target.wants`).
- **Default Target**: Always link `default.target` to `graphical.target`.
- **Dependencies**: Ensure `accountsservice` is in `deps.bst`.

### Virtualization Workarounds
- **Software Rendering**: Use `Environment=QT_QUICK_BACKEND=software` in an SDDM service drop-in to bypass GPU issues in VMs.
- **Linker Cache**: Use `chroot /layer ldconfig` to ensure libraries are resolvable at boot.

### Image Generation
- **Disk Allocation**: Use `fallocate` instead of `truncate` for `bootc install` targets to prevent loop device corruption.
- **Filesystem**: Prefer **XFS** for the bootable RAW image filesystem.
- **Persistence**: Always call `sync` before closing loop devices or starting libvirt/QEMU.
