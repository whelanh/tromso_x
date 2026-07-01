kind: script
description: Minimal KDE Linux OCI image (KDE Linux base + essential config only — no Aurora overlay)

build-depends:
  - kde-build-meta.bst:freedesktop-sdk.bst:components/fakecap.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/oci-builder.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/glib.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/sed.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:vm/prepare-image.bst
  - filename: oci/kde-linux/image.bst
    config:
      location: /parent
  - filename: oci/layers/kde-minimal.bst
    config:
      location: /layer

environment:
  LD_PRELOAD: /usr/libexec/fakecap/fakecap.so
  FAKECAP_DB: /fakecap

variables:
  sysroot-seed: a1b2c3d4-e5f6-7890-abcd-ef1234567890
  (?):
  - arch == "x86_64":
      go-arch: amd64
  - arch == "aarch64":
      go-arch: arm64

config:
  commands:
    - mkdir /fakecap
    - |
      # depmod treats every entry in lib/modules/ as a kernel version string;
      # remove stray JSON files (e.g. KWin effect configs) before it runs.
      find /layer/lib/modules/ -name "*.json" -delete 2>/dev/null || true
    - |
      prepare-image.sh \
         --sysroot /layer \
         --initscripts /initial_scripts \
         --seed "%{sysroot-seed}" \
         --noroot --noboot

    - |
      systemd-sysusers --root /layer

    - |
      if [ -d /layer/usr/share/glib-2.0/schemas ]; then
        glib-compile-schemas /layer/usr/share/glib-2.0/schemas || true
      fi

    - |
      systemctl --root=/layer enable sshd.service || true
      # Enable flatpak-system-helper so Discover can interact with Flatpak
      systemctl --root=/layer enable flatpak-system-helper.service || true
      # Force software rendering for plasmalogin QML greeter in VMs
      mkdir -p /layer/usr/lib/systemd/system/plasmalogin.service.d
      cat > /layer/usr/lib/systemd/system/plasmalogin.service.d/software-render.conf << 'EOF'
      [Service]
      Environment=QT_QUICK_BACKEND=software
      Environment=KWIN_COMPOSE=Q
      EOF

    - |
      # The shadow package seeds empty subordinate ID files; populate them
      # so rootless podman in the greeter session gets a real range.
      for dir in /layer/etc /layer/usr/share/factory/etc; do
        mkdir -p "$dir"
        printf '%s\n' 'plasmalogin:100000:65536' >"$dir/subuid"
        printf '%s\n' 'plasmalogin:100000:65536' >"$dir/subgid"
        chmod 0644 "$dir/subuid" "$dir/subgid"
      done
      # Compose/export loses capabilities applied earlier in integration
      # commands, so restore them on the final filesystem that bootc installs.
      setcap cap_sys_nice+ep /layer/usr/bin/kwin_wayland
      setcap cap_setuid+ep /layer/usr/bin/newuidmap
      setcap cap_setgid+ep /layer/usr/bin/newgidmap
      # Compose also strips the setuid bit from sudo; restore it so users
      # can run privileged commands.  The stack integration command does this
      # too, but compose may re-strip it.
      chmod u+s /layer/usr/bin/sudo || true
      # Flatpak requires fusermount3 to have setuid so non-root users
      # can mount/unmount FUSE filesystems for app installation.
      chmod u+s /layer/usr/bin/fusermount3 || true
      # Refresh linker cache in the layer so the login manager can resolve
      # Qt6 libraries at first boot.  Use ldconfig -r (Dakota convention)
      # which scans the layer rootfs and writes /etc/ld.so.cache.
      if [ ! -f /layer/etc/ld.so.conf ]; then
        printf 'include /etc/ld.so.conf.d/*.conf\n' > /layer/etc/ld.so.conf
      fi
      ldconfig -r /layer -f /layer/etc/ld.so.conf 2>/dev/null || \
        chroot /layer ldconfig 2>/dev/null || true
    - |
      mkdir -p /fc-work /fc-merged
      if timeout 30 mount -t overlay overlay \
           -o "lowerdir=/parent,upperdir=/layer,workdir=/fc-work" \
           /fc-merged 2>/dev/null; then
        timeout 60 chroot /fc-merged fc-cache -f 2>/dev/null || true
        umount /fc-merged || true
      else
        timeout 60 chroot /layer fc-cache -f 2>/dev/null || true
      fi
      rm -rf /fc-merged /fc-work 2>/dev/null || true
    # Extract CA certificates in the target layer instead of the build sandbox.
    # Since chroot is not permitted in this sandbox, and prepare-image.sh
    # already ran update-ca-trust inside the sandbox root, we can just copy
    # the generated certificates from the sandbox's /etc to the layer.
    - |
      if [ -d /etc/pki/ca-trust/extracted ]; then
        mkdir -p /layer/etc/pki/ca-trust/extracted
        cp -a /etc/pki/ca-trust/extracted/. /layer/etc/pki/ca-trust/extracted/
      fi
    - |
      # Force an explicit font family in the Breeze QML that renders the
      # greeter / lock-screen text. Live guest testing showed this changes the
      # framebuffer, while rebuilding font cache alone did not.  These
      # org.kde.breeze look-and-feel components are shared by the
      # plasma-login-manager greeter and the screen locker.
      action_button_qml=/layer/usr/lib/qml/org/kde/breeze/components/ActionButton.qml
      if [ -f "$action_button_qml" ]; then
        sed -i 's|^\([[:space:]]*font\.pointSize: Kirigami\.Theme\.defaultFont\.pointSize + 1\)$|\1\
            font.family: "Noto Sans"|' "$action_button_qml"
      fi
      user_delegate_qml=/layer/usr/lib/qml/org/kde/breeze/components/UserDelegate.qml
      if [ -f "$user_delegate_qml" ]; then
        sed -i 's|^\([[:space:]]*font\.pointSize: wrapper\.fontSize + 4\)$|\1\
              font.family: "Noto Sans"|' "$user_delegate_qml"
      fi
      session_management_qml=/layer/usr/lib/qml/org/kde/breeze/components/SessionManagementScreen.qml
      if [ -f "$session_management_qml" ]; then
        sed -i 's|^\([[:space:]]*font\.pointSize: root\.fontSize\)$|\1\
                  font.family: "Noto Sans"|' "$session_management_qml"
      fi
      clock_qml=/layer/usr/lib/qml/org/kde/breeze/components/Clock.qml
      if [ -f "$clock_qml" ]; then
        sed -i 's|^\([[:space:]]*font\.pointSize: Math\.round(Kirigami\.Theme\.defaultFont\.pointSize \* 7\.2)\)$|\1\
              font.family: "Noto Sans"|' "$clock_qml"
        sed -i 's|^\([[:space:]]*font\.pointSize: Math\.round(Kirigami\.Theme\.defaultFont\.pointSize \* 2\.4)\)$|\1\
              font.family: "Noto Sans"|' "$clock_qml"
      fi
      battery_qml=/layer/usr/lib/qml/org/kde/breeze/components/Battery.qml
      if [ -f "$battery_qml" ]; then
        sed -i 's|^\([[:space:]]*font\.pointSize: root\.fontSize\)$|\1\
              font.family: "Noto Sans"|' "$battery_qml"
      fi

    # Configure Flathub as a system-wide Flatpak remote so Discover
    # shows applications on first boot without manual setup.
    - |
      mkdir -p /layer/etc/flatpak/remotes.d
      cat > /layer/etc/flatpak/remotes.d/flathub.flatpakrepo << 'REPOEOF'
      [Flatpak Repo]
      Title=Flathub
      Url=https://dl.flathub.org/repo/
      Homepage=https://flathub.org
      Comment=Central repository of Flatpak applications
      Description=Discover flatpak applications from the Flathub ecosystem
      Icon=https://flathub.org/repo/logo.svg
      GPGKey=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
      REPOEOF

    # Merge parent OCI rootfs (ALL layers) with /layer into a single
    # rootfs.  Move parent's /usr/etc content into /etc (bootc/ostree
    # convention expects base config in /etc, not /usr/etc, and will
    # migrate it internally during deployment).  A single-layer OCI
    # avoids the "Tree contains both /etc and /usr/etc" error that
    # occurs when bootc extracts multi-layer images sequentially
    # (whiteouts in OCI layers are not processed by bootc/ostree).
    - |
      python3 << 'PYEOF'
      import json, os, shutil, sys, tarfile, gzip

      def _remove(path):
          if not os.path.lexists(path):
              return
          if os.path.islink(path) or not os.path.isdir(path):
              os.unlink(path)
          else:
              shutil.rmtree(path)

      def robust_merge(src, dst):
          if not os.path.isdir(dst):
              os.makedirs(dst, exist_ok=True)
          for name in os.listdir(src):
              s = os.path.join(src, name)
              d = os.path.join(dst, name)
              if os.path.islink(s):
                  _remove(d)
                  os.symlink(os.readlink(s), d)
              elif os.path.isdir(s):
                  if os.path.lexists(d) and not (os.path.isdir(d) and not os.path.islink(d)):
                      _remove(d)
                  if not os.path.isdir(d):
                      os.makedirs(d)
                  robust_merge(s, d)
              else:
                  _remove(d)
                  shutil.copy2(s, d)

      def extract_tar(tar, path):
          for member in tar.getmembers():
              dest = os.path.join(path, member.name)
              if member.isdir():
                  os.makedirs(dest, exist_ok=True)
              elif member.issym():
                  parent = os.path.dirname(dest)
                  os.makedirs(parent, exist_ok=True)
                  if os.path.lexists(dest):
                      _remove(dest)
                  os.symlink(member.linkname, dest)
              elif member.islnk():
                  parent = os.path.dirname(dest)
                  os.makedirs(parent, exist_ok=True)
                  if os.path.lexists(dest):
                      _remove(dest)
                  os.link(os.path.join(path, member.linkname), dest)
              else:
                  parent = os.path.dirname(dest)
                  os.makedirs(parent, exist_ok=True)
                  if os.path.lexists(dest):
                      _remove(dest)
                  src = tar.extractfile(member)
                  if src is not None:
                      with src, open(dest, 'wb') as dst:
                          shutil.copyfileobj(src, dst)

      parent = "/parent"
      layer_src = "/layer"
      merged = "/layer-merged"

      if os.path.isdir(merged):
          shutil.rmtree(merged)
      os.makedirs(merged)

      if not (os.path.isdir(parent) and os.path.isfile(os.path.join(parent, "index.json"))):
          print("Parent is not an OCI layout — using /layer as-is", file=sys.stderr)
          robust_merge(layer_src, merged)
      else:
          parent_out = "/parent-extracted"
          if os.path.isdir(parent_out):
              shutil.rmtree(parent_out)
          os.makedirs(parent_out)

          with open(os.path.join(parent, "index.json")) as f:
              index = json.load(f)
          mdigest = index["manifests"][0]["digest"].replace("sha256:", "")
          with open(os.path.join(parent, "blobs", "sha256", mdigest)) as f:
              manifest = json.load(f)

          for layer in manifest["layers"]:
              ldigest = layer["digest"].replace("sha256:", "")
              blob = os.path.join(parent, "blobs", "sha256", ldigest)
              mt = layer.get("mediaType", "")
              if os.path.isdir(blob):
                  for name in os.listdir(blob):
                      s = os.path.join(blob, name)
                      d = os.path.join(parent_out, name)
                      if os.path.islink(s):
                          if os.path.lexists(d):
                              _remove(d)
                          os.symlink(os.readlink(s), d)
                      elif os.path.isdir(s):
                          shutil.copytree(s, d, symlinks=True, dirs_exist_ok=True)
                      else:
                          shutil.copy2(s, d)
              elif "gzip" in mt:
                  with gzip.open(blob) as gz:
                      with tarfile.open(fileobj=gz) as tar:
                          extract_tar(tar, parent_out)
              else:
                  with tarfile.open(blob) as tar:
                      extract_tar(tar, parent_out)

          # Merge parent into merged rootfs — move /usr/etc → /etc so
          # bootc's ostree commit sees a single config directory.
          parent_usr_etc = os.path.join(parent_out, "usr", "etc")
          if os.path.isdir(parent_usr_etc):
              robust_merge(parent_usr_etc, os.path.join(merged, "etc"))
              shutil.rmtree(parent_usr_etc)
              print("Parent /usretc merged into /etc", file=sys.stderr)
          robust_merge(parent_out, merged)
          shutil.rmtree(parent_out)

          # Merge /layer on top (overwrites /etc entries with layer config)
          layer_usr_etc = os.path.join(layer_src, "usr", "etc")
          if os.path.isdir(layer_usr_etc):
              robust_merge(layer_usr_etc, os.path.join(merged, "etc"))
              shutil.rmtree(layer_usr_etc)
              print("Layer /usretc merged into /etc", file=sys.stderr)
          robust_merge(layer_src, merged)

      # Ensure no /usr/etc remains in the merged rootfs
      usr_etc_path = os.path.join(merged, "usr", "etc")
      if os.path.isdir(usr_etc_path):
          shutil.rmtree(usr_etc_path)
          print("Removed stray /usr/etc from merged rootfs", file=sys.stderr)

      for d in ("ostree",):
          _remove(os.path.join(merged, d))

      with open("/merged-path", "w") as f:
          f.write(merged)
      PYEOF

    # Override prepare-root.conf to disable composefs. Written after
    # merge to ensure it lands in the final single-layer rootfs.
    - |
      printf '[composefs]\nenabled = no\n\n[sysroot]\nreadonly = true\n' > "$(cat /merged-path)/usr/lib/ostree/prepare-root.conf"

    - |
      cd "%{install-root}"
      build-oci <<EOF
      mode: oci
      gzip: disabled
      images:
      - os: linux
        architecture: "%{go-arch}"
        layer: $(cat /merged-path)
        comment: "KDE Linux Minimal - Pure KDE Plasma desktop (no Aurora overlay)"
        config:
          Labels:
            'com.github.containers.toolbox': 'true'
            'org.opencontainers.image.title': 'KDE Linux Minimal'
            'org.opencontainers.image.description': 'KDE Linux Plasma desktop based on freedesktop-sdk, no Aurora overlay'
            'org.opencontainers.image.vendor': 'Hanthor'
            'org.opencontainers.image.licenses': 'Apache-2.0'
            'org.opencontainers.image.url': 'https://github.com/hanthor/tromso'
            'org.opencontainers.image.source': 'https://github.com/hanthor/tromso'
            'containers.bootc': '1'
        index-annotations:
          'org.opencontainers.image.ref.name': 'ghcr.io/hanthor/tromso:kde-minimal'
      EOF
