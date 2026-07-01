kind: script
description: Minimal KDE Linux OCI image — self-contained (Dakota pattern, no parent OCI)

build-depends:
  - kde-build-meta.bst:freedesktop-sdk.bst:components/fakecap.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/oci-builder.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/glib.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/sed.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:vm/prepare-image.bst
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
      systemctl --root=/layer enable flatpak-system-helper.service || true
      # Force software rendering for plasmalogin QML greeter in VMs
      mkdir -p /layer/usr/lib/systemd/system/plasmalogin.service.d
      cat > /layer/usr/lib/systemd/system/plasmalogin.service.d/software-render.conf << 'EOF'
      [Service]
      Environment=QT_QUICK_BACKEND=software
      Environment=KWIN_COMPOSE=Q
      EOF

    - |
      # Dakota convention: bootc images must not have both /etc and /usr/etc.
      # /usr/etc is an ostree implementation detail generated client-side;
      # the image should only ship /etc.
      if [ -d /layer/usr/etc ]; then
        mkdir -p /layer/etc
        cp -a /layer/usr/etc/. /layer/etc/
        rm -rf /layer/usr/etc
      fi

    - |
      for dir in /layer/etc /layer/usr/share/factory/etc; do
        mkdir -p "$dir"
        printf '%s\n' 'plasmalogin:100000:65536' >"$dir/subuid"
        printf '%s\n' 'plasmalogin:100000:65536' >"$dir/subgid"
        chmod 0644 "$dir/subuid" "$dir/subgid"
      done
      setcap cap_sys_nice+ep /layer/usr/bin/kwin_wayland
      setcap cap_setuid+ep /layer/usr/bin/newuidmap
      setcap cap_setgid+ep /layer/usr/bin/newgidmap
      chmod u+s /layer/usr/bin/sudo || true
      chmod u+s /layer/usr/bin/fusermount3 || true
      if [ ! -f /layer/etc/ld.so.conf ]; then
        printf 'include /etc/ld.so.conf.d/*.conf\n' > /layer/etc/ld.so.conf
      fi
      ldconfig -r /layer -f /layer/etc/ld.so.conf 2>/dev/null || \
        chroot /layer ldconfig 2>/dev/null || true

    - |
      timeout 60 chroot /layer fc-cache -f 2>/dev/null || true

    - |
      if [ -d /etc/pki/ca-trust/extracted ]; then
        mkdir -p /layer/etc/pki/ca-trust/extracted
        cp -a /etc/pki/ca-trust/extracted/. /layer/etc/pki/ca-trust/extracted/
      fi

    - |
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
      mkdir -p /layer/etc/flatpak/remotes.d
      cat > /layer/etc/flatpak/remotes.d/flathub.flatpakrepo << 'REPOEOF'
      [Flatpak Repo]
      Title=Flathub
      Url=https://dl.flathub.org/repo/
      Homepage=https://flathub.org
      Comment=Central repository of Flatpak applications
      Description=Discover flatpak applications from the Flathub ecosystem
      Icon=https://flathub.org/repo/logo.svg
      GPGKey=mQINBFlD2sABEADsiUZUOYBg1UdDaWkEdJYkTSZD68214m8Q1fbrP5AptaUfCl8KYKFMNoAJRBXn9FbE6q6VBzghHXj/rSnA8WPnkbaEWR7xltOqzB1yHpCQ1l8xSfH5N02DMUBSRtD/rOYsBKbaJcOgW0K21sX+BecMY/AI2yADvCJEjhVKrjR9yfRX+NQEhDcbXUFRGt9ZT+TI5yT4xcwbvvTu7aFUR/dH7+wjrQ7lzoGlZGFFrQXSs2WI0WaYHWDeCwymtohXryF8lcWQkhH8UhfNJVBJFgCY8Q6UHkZG0FxMu8xnIDBMjBmSZKwKQn0nwzwM2afskZEnmNPYDI8nuNsSZBZSAw+ThhkdCZHZZRwzmjzyRuLLVFpOj3XryXwZcSefNMPDkZAuWWzPYjxS80cm2hG1WfqrG0Gl8+iX69cbQchb7gbEb0RtqNskTo9DDmO0bNKNnMbzmIJ3/rTbSahKSwtewklqSP/01o0WKZiy+n/RAkUKOFBprjJtWOZkc8SPXV/rnoS2dWsJWQZhuPPtv3tefdDiEyp7ePrfgfKxuHpZES0IZRiFI4J/nAUP5bix+srcIxOVqAam68CbAlPvWTivRUMRVbKjJiGXIOJ78wAMjqPg3QIC0GQ0EPAWwAOzzpdgbnG7TCQetaVV8rSYCuirlPYN+bJIwBtkOC9SWLoPMVZTwQARAQABtC5GbGF0aHViIFJlcG8gU2lnbmluZyBLZXkgPGZsYXRodWJAZmxhdGh1Yi5vcmc+iQJUBBMBCAA+FiEEblwF2XnHba+TwIE1QYTdTZB6fK4FAllD2sACGwMFCRLMAwAFCwkIBwIGFQgJCgsCBBYCAwECHgECF4AACgkQQYTdTZB6fK5RJQ/+Ptd4sWxaiAW91FFk7+wmYOkEe1NY2UDNJjEEz34PNP/1RoxveHDt43kYJQ23OWaPJuZAbu+fWtjRYcMBzOsMCaFcRSHFiDIC9aTp4ux/mo+IEeyarYt/oyKb5t5lta6xaAqg7rwt65jW5/aQjnS4h7eFZ+dAKta7Y/fljNrOznUp81/SMcx4QA5G2Pw0hs4Xrxg59oONOTFGBgA6FF8WQghrpR7SnEe0FSEOVsAjwQ13Cfkfa7b70omXSWp7GWfUzgBKyoWxKTqzMN3RQHjjhPJcsQnrqH5enUu4Pcb2LcMFpzimHnUgb9ft72DP5wxfzHGAWOUiUXHbAekfq5iFks8cha/RST6wkxG3Rf44Zn09aOxh1btMcGL+5xb1G0BuCQnA0fP/kDYIPwh9z22EqwRQOspIcvGeLVkFeIfubxpcMdOfQqQnZtHMCabV5Q/Rk9K1ZGc8M2hlg8gHbXMFch2xJ0Wu72eXbA/UY5MskEeBgawTQnQOK/vNm7t0AJMpWK26Qg6178UmRghmeZDj9uNRc3EI1nSbgvmGlpDmCxaAGqaGL1zW4KPW5yN25/qeqXcgCvUjZLI9PNq3Kvizp1lUrbx7heRiSoazCucvHQ1VHUzcPVLUKKTkoTP8okThnRRRsBcZ1+jI4yMWIDLOCT7IW3FePr+3xyuy5eEo9a25Ag0EWUPa7AEQALT/CmSyZ8LWlRYQZKYw417p7Z2hxqd6TjwkwM3IQ1irumkWcTZBZIbBgrSOg6CcXD2oWydCQHWi9qaxhuhEl2bJL5LskmBcMxVdQeD0LLHd8QUnbnnIby8ocvWN1alPfvJFjCUTrmD22U1ycOzRw2lIe4kiQONbOZtdWrVImQQSndjFlisitbmlWHvHm2lOOYy8+GJB7YffVV193hmnBSJffCy4bvkuLxsI+n1DhOzc7MPV3z6HGk4HiEcF0yyt9tCYhpsxHFdBoq2h771HfAcS0s98EVAqYMFnf9em+4cnYpdI6mhIfS1FQiKl6DBAYA8tT3ggla00DurPo0JwX/zN+PaO5h/6O9aCZwV7G6rbkgMuqMergXaf8oP38gr0z+MqWnkfM63Bodq68GP4l4h... (line truncated to 2000 chars)
      REPOEOF

    - |
      printf '[composefs]\nenabled = no\n\n[sysroot]\nreadonly = true\n' > /layer/usr/lib/ostree/prepare-root.conf

    - |
      cd "%{install-root}"
      build-oci <<EOF
      mode: oci
      gzip: disabled
      images:
      - os: linux
        architecture: "%{go-arch}"
        layer: /layer
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
