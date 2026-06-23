kind: script
description: KDE Linux OCI image (full desktop + system) — Aurora fork without bootc build

build-depends:
- kde-build-meta.bst:freedesktop-sdk.bst:components/fakecap.bst
- kde-build-meta.bst:freedesktop-sdk.bst:components/oci-builder.bst
- kde-build-meta.bst:freedesktop-sdk.bst:vm/prepare-image.bst
- kde-build-meta.bst:oci/kde-linux/init-scripts.bst
- filename: kde-build-meta.bst:oci/platform/image.bst
  config:
    location: /parent
- filename: oci/kde-linux/filesystem.bst
  config:
    location: /layer

environment:
  LD_PRELOAD: /usr/libexec/fakecap/fakecap.so
  FAKECAP_DB: /fakecap

variables:
  sysroot-seed: b57666f6-0fe5-4310-adff-f256936d164d
  (?):
  - arch == "x86_64":
      go-arch: amd64
  - arch == "aarch64":
      go-arch: arm64

config:
  commands:
  - mkdir /fakecap
  # Clean up /lib/modules entirely - depmod will rebuild what it needs
  - |
    rm -rf /layer/lib/modules
    mkdir -p /layer/lib/modules
  - |
    prepare-image.sh \
       --sysroot /layer \
       --initscripts /initial_scripts \
       --seed "%{sysroot-seed}" \
       --noroot --noboot >/dev/null

  - |
    systemd-sysusers --root /layer

  - |
    glib-compile-schemas /layer/usr/share/glib-2.0/schemas

  # Normalize /layer to match the parent image's /etc vs /usr/etc
  # convention.  bootc requires exactly one of them in the merged OCI
  # image; if the parent has /etc/ and the layer has /usr/etc/ the
  # merged result contains both and deployment fails.  When the parent
  # has neither, default to the OSTree standard: /usr/etc/.
  - |
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
    gzip: disabled
    images:
    - os: linux
      architecture: "%{go-arch}"
      parent:
        image: /parent
      layer: /layer
      comment: "KDE Linux image (full desktop)"
      config:
        Labels:
          'com.github.containers.toolbox': 'true'
          'org.opencontainers.image.title': 'KDE Linux'
          'org.opencontainers.image.description': 'A KDE Plasma desktop image based on freedesktop-sdk'
          'org.opencontainers.image.vendor': 'Hanthor'
          'org.opencontainers.image.licenses': 'Apache-2.0'
          'org.opencontainers.image.url': 'https://github.com/hanthor/tromso'
          'org.opencontainers.image.source': 'https://github.com/hanthor/tromso'
          'containers.bootc': '1'
        index-annotations:
          'org.opencontainers.image.ref.name': 'quay.io/kde_infrastructure/kde-build-meta:image'
    EOF
