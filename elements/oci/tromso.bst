kind: script
description: Aurora KDE Linux OCI image (layered on KDE Linux OS)

build-depends:
  - kde-build-meta.bst:freedesktop-sdk.bst:components/fakecap.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/oci-builder.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/glib.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/sed.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:vm/prepare-image.bst
  - filename: oci/kde-linux/image.bst
    config:
      location: /parent
  - filename: oci/layers/tromso.bst
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
        glib-compile-schemas /layer/usr/share/glib-2.0/schemas
      fi

    - |
      systemctl --root=/layer enable sshd.service || true
      # Enable flatpak-system-helper so Discover can interact with Flatpak
      systemctl --root=/layer enable flatpak-system-helper.service || true

    # The OCI image chain uses /usr/etc/ (the OSTree standard).  On
    # bootc-deployed systems /etc/ at runtime is a tmpfs; all system
    # default configs must live in /usr/etc/.  Before build-oci we check
    # the parent and normalize the layer to match — this avoids the
    # "Tree contains both /etc and /usr/etc" deployment error.
    - |
      # The shadow package seeds empty subordinate ID files; populate them
      # so rootless podman in the greeter session gets a real range.
      for dir in /layer/usr/etc /layer/usr/share/factory/etc; do
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
      # Refresh linker cache in the composed rootfs so the login manager can
      # resolve Qt6
      # libraries installed under /usr/lib at first boot.
      # Qt6 core libs live in /parent/usr/lib (KDE Linux base image); chrooting
      # only into /layer misses them.  Mount parent+layer as an overlay so
      # ldconfig sees the full merged /usr/lib and writes the correct cache into
      # /layer/etc/ld.so.cache (overlay upper-dir write-back).
      if [ ! -f /layer/usr/etc/ld.so.conf ]; then
        printf 'include /etc/ld.so.conf.d/*.conf\n' > /layer/usr/etc/ld.so.conf
      fi
      mkdir -p /ld-work /ld-merged
      if timeout 30 mount -t overlay overlay \
           -o "lowerdir=/parent,upperdir=/layer,workdir=/ld-work" \
           /ld-merged 2>/dev/null; then
        timeout 60 chroot /ld-merged ldconfig || true
        umount /ld-merged || true
      else
        timeout 60 chroot /layer ldconfig || true
      fi
      rm -rf /ld-merged /ld-work 2>/dev/null || true
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
    # the generated certificates from the sandbox's /etc to the layer's /usr/etc.
    - |
      if [ -d /etc/pki/ca-trust/extracted ]; then
        mkdir -p /layer/usr/etc/pki/ca-trust/extracted
        cp -a /etc/pki/ca-trust/extracted/. /layer/usr/etc/pki/ca-trust/extracted/
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

    - |
      # Normalize /layer to match the parent image's /etc vs /usr/etc
      # convention.  bootc requires exactly one of them in the merged OCI
      # image.  When the parent has neither, default to the OSTree standard:
      # /usr/etc/.
      if [ -d /parent/etc ] && [ -d /parent/usr/etc ]; then
        echo "ERROR: Parent image has both /etc and /usr/etc" >&2
        exit 1
      fi
      if [ -d /parent/usr/etc ] || ( [ ! -d /parent/etc ] && [ ! -d /parent/usr/etc ] ); then
        # Parent uses /usr/etc (or has neither) — use /usr/etc convention
        if [ -d /layer/etc ]; then
          mkdir -p /layer/usr/etc
          cp -a /layer/etc/. /layer/usr/etc/
          rm -rf /layer/etc
        fi
      elif [ -d /parent/etc ]; then
        # Parent uses /etc — match it
        if [ -d /layer/usr/etc ]; then
          mkdir -p /layer/etc
          cp -a /layer/usr/etc/. /layer/etc/
          rm -rf /layer/usr/etc
        fi
      fi

    - |
      cd "%{install-root}"
      build-oci <<EOF
      mode: oci
      gzip: gzip
      images:
      - os: linux
        architecture: "%{go-arch}"
        parent:
          image: /parent
        layer: /layer
        comment: "Aurora Tromso - KDE Plasma desktop (layered on KDE Linux)"
        config:
          Labels:
            'com.github.containers.toolbox': 'true'
            'org.opencontainers.image.title': 'Aurora Tromso'
            'org.opencontainers.image.description': 'Aurora Tromso KDE Plasma desktop, layered on KDE Linux'
            'org.opencontainers.image.vendor': 'Hanthor'
            'org.opencontainers.image.licenses': 'Apache-2.0'
            'org.opencontainers.image.url': 'https://github.com/hanthor/tromso'
            'org.opencontainers.image.source': 'https://github.com/hanthor/tromso'
            'containers.bootc': '1'
        index-annotations:
          'org.opencontainers.image.ref.name': 'ghcr.io/hanthor/tromso:latest'
      EOF
