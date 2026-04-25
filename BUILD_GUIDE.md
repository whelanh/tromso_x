# Aurora KDE Linux - Build & Boot Guide

**Status:** Build in progress with kernel package  
**Started:** 2026-04-25 ~10:32 UTC  
**Goal:** Bootable VM with SSH support

## 🔨 Current Build Status

Build started with critical kernel package (linux.bst) added to dependencies.

### What's Being Built
- Linux kernel (vmlinuz, System.map, modules)
- OpenSSH (sshd service)
- KDE Plasma desktop environment
- Bootable OS infrastructure (bootc config, initramfs, grub)
- OCI image composition into single artifact

### Build Phases
1. **Fetch & Validate** (in progress)
   - Pulling cached artifacts from remote cache server
   - Checking/downloading sources

2. **Build Dependencies** (~15-20 min remaining)
   - Compiling base freedesktop-sdk components
   - Building KDE Plasma stack
   - Compiling kernel with custom config

3. **Assemble OCI Image** (~5 min)
   - Composing layers: runtime-minimal → KDE apps → bootable OS infra
   - Creating unified OCI image artifact

4. **Export** (~2 min)
   - Checkout OCI artifact from BuildStream
   - Load into podman storage as `aurora:latest`
   - Optimize image with squash-all

## 📋 After Build Completes (Automated or Manual)

### Option A: Automatic Workflow (Simplest)
If the build completes successfully:
```bash
just build          # Automatically runs bst build + export
just generate-bootable-image
just boot-vm
```

### Option B: Step-by-Step Manual

**1. Wait for build to complete:**
```bash
# Monitor in one terminal:
tail -f /var/tmp/aurora-build.log | grep -E "SUCCESS|FAILED|oci/aurora.bst"

# Or use dashboard:
just dashboard  # Opens web UI at http://localhost:8765
```

**2. Once build shows "oci/aurora.bst SUCCESS", export the image:**
```bash
just export
# This creates: localhost/aurora:latest in podman
```

**3. Generate bootable disk:**
```bash
just generate-bootable-image
# Creates: bootable.raw (30GB) with proper partitions
```

**4. Boot the VM:**
```bash
just boot-vm
# Boots in QEMU with:
# - VNC: 127.0.0.1:5900 (use vncviewer or web viewer)
# - SSH: 127.0.0.1:2222 → root (after boot completes)
# - Serial: stdio (kernel logs in terminal)
```

## 🧪 Testing After Boot

### Via Serial Console (automatic with boot-vm)
```
watch output for:
[ OK ] Started D-Bus Session Bus
[ OK ] Started Login Service.
...then systemd should reach target boot-complete
```

### Via SSH (once boot completes, ~30-60 seconds)
```bash
# Wait 30 seconds for systemd to initialize, then:
ssh -p 2222 -o ConnectTimeout=3 root@127.0.0.1

# Verify bootc is present (bootable):
ssh -p 2222 root@127.0.0.1 'bootc status'

# Check kernel is loaded:
ssh -p 2222 root@127.0.0.1 'uname -a'

# Verify SSH service:
ssh -p 2222 root@127.0.0.1 'systemctl status sshd'

# Check mounted partitions:
ssh -p 2222 root@127.0.0.1 'mount | grep root'
```

### Via VNC
```bash
# In another terminal:
vncviewer 127.0.0.1:5900
# Or use web: http://127.0.0.1:5900 in browser if vncviewer unavailable
```

## 📊 Key Differences From Previous Attempt

### What Was Wrong Before
- ❌ Aurora image was **container-based**, not **bootable OS**
- ❌ Missing vmlinuz kernel files
- ❌ Missing systemd init system (supposedly in runtime-minimal, but not verified in image)
- ❌ bootc couldn't create bootable disk from incomplete image
- ❌ Result: blank disk with 0 bytes written

### What's Fixed Now
- ✅ **Added linux.bst** (kernel with vmlinuz)
- ✅ **Added linux-firmware.bst** (firmware files for hardware)
- ✅ **SSH enabled** (openssh.bst + systemctl enable sshd)
- ✅ **Boot infrastructure** (bootc-config, initramfs, bootloader config)
- ✅ **Proper OCI structure** for bootc to parse

### Result Expected
- ✓ bootc install-to-disk should succeed
- ✓ Disk will contain actual kernel, root filesystem, bootloader
- ✓ QEMU will boot properly with UEFI + BIOS fallback
- ✓ SSH will be available after boot completes

## 🐛 Troubleshooting

### Build Fails
```bash
# Check build log for errors:
tail -100 /var/tmp/aurora-build.log | grep -i "error\|failed"

# Common issues:
# 1. Network timeout fetching sources → wait, buildstream will retry
# 2. Cache server unreachable → fallback to build from source
# 3. Missing package → check deps.bst for typos

# Rebuild from scratch:
just bst build oci/aurora.bst --rebuild
```

### Boot Hangs
```bash
# Serial console will show where it hangs
# Common hangs:
# - UEFI firmware: stuck at firmware menu (timeout)
# - Kernel: missing drivers (would show kernel panic)
# - systemd: service dependency cycle (would show failures)

# Kill VM:
Ctrl+C in boot-vm terminal, or: pkill -f qemu-system-x86_64
```

### SSH Won't Connect
```bash
# VM must finish booting first (30-60 seconds)
watch serial console for: [ OK ] reached target boot-complete

# If SSH still fails after boot:
ssh -v -p 2222 root@127.0.0.1  # verbose output
# Check if sshd is running:
ssh -p 2222 root@127.0.0.1 'systemctl status sshd'

# If sshd service failed:
# Check OS-release to confirm SSH enabled in image:
ssh -p 2222 root@127.0.0.1 'systemctl list-units --type=service | grep sshd'
```

### Disk Creation Fails
```bash
# "Multiple commit objects found" error (from before):
# This was OCI corruption from Dockerfile layer
# FIXED: No more Dockerfile, using pure BuildStream build

# "No such file or directory /data/bootable.raw":
just generate-bootable-image  # will create it
# Or manually: fallocate -l 30G bootable.raw

# Permission denied on loopback:
# generate-bootable-image uses sudo, make sure it's in sudoers
sudo -v  # test sudo works
```

## 📂 Important Files

| File | Purpose |
|------|---------|
| `elements/aurora/deps.bst` | Application dependencies (now includes linux.bst) |
| `elements/oci/aurora.bst` | OCI image composition + SSH enablement |
| `elements/oci/layers/aurora-stack.bst` | Bootable OS infrastructure |
| `Justfile` | All build/boot/export commands |
| `/var/tmp/aurora-build.log` | Full build log (monitor this) |
| `bootable.raw` | Final bootable disk image (after generation) |

## 🎯 Next Steps After VM Boots

### Immediate
1. Verify boot works (serial console)
2. Verify SSH works (ssh root@127.0.0.1 -p 2222)
3. Verify bootc is present (`bootc status`)

### Optional (Future)
1. Create ISO for distribution
2. Add persistent SSH host keys
3. Configure network persistence
4. Add KDE desktop graphical configuration
5. Test both UEFI and BIOS boot paths

## 📞 Quick Command Reference

```bash
# Monitoring
just log                    # tail build log
just dashboard              # web UI

# Building  
just bst-build             # build in background
just export                # export OCI image

# Booting
just generate-bootable-image  # create bootable.raw
just boot-vm               # boot in QEMU

# SSH (after boot)
ssh -p 2222 root@127.0.0.1 'bootc status'
ssh -p 2222 root@127.0.0.1 'systemctl status sshd'

# Cleanup
just clean                 # remove bootable.raw, temp files
```

---

**Current estimate:** Build completes in 15-25 minutes. Monitor `/var/tmp/aurora-build.log` for progress.
