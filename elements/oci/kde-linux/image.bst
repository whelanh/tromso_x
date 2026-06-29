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
    glib-compile-schemas /layer/usr/share/glib-2.0/schemas || true

  # Merge parent OCI rootfs (ALL layers) with /layer into a single
  # rootfs using cp -a (handles symlinks properly), then normalize
  # /usr/etc → /etc so bootc sees exactly one.  This follows Dakota's
  # single-layer approach and avoids the "Tree contains both /etc and
  # /usr/etc" deployment error.
  - |
    mkdir -p /layer-merged
    python3 << 'PYEOF'
    import json, os, shutil, sys, tarfile, gzip

    parent = "/parent"
    layer_src = "/layer"
    merged = "/layer-merged"

    if not (os.path.isdir(parent) and os.path.isfile(os.path.join(parent, "index.json"))):
        print("Parent is not an OCI layout — using /layer as-is", file=sys.stderr)
        with open("/use-layer-as-is", "w") as f:
            f.write("1")
        sys.exit(0)

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
                src = os.path.join(blob, name)
                dst = os.path.join(parent_out, name)
                if os.path.isdir(src):
                    shutil.copytree(src, dst, symlinks=True, dirs_exist_ok=True)
                else:
                    shutil.copy2(src, dst)
        elif "gzip" in mt:
            with gzip.open(blob) as gz:
                with tarfile.open(fileobj=gz) as tar:
                    tar.extractall(parent_out)
        else:
            with tarfile.open(blob) as tar:
                tar.extractall(parent_out)
    PYEOF
    if [ -f /use-layer-as-is ]; then
      cp -a /layer/. /layer-merged/
    else
      cp -a /parent-extracted/. /layer-merged/
      rm -rf /parent-extracted
      cp -a /layer/. /layer-merged/
    fi

  # Normalize /usr/etc → /etc on the merged rootfs
  - |
    python3 << 'PYEOF'
    import os, shutil, sys

    merged = "/layer-merged"
    usr_etc = os.path.join(merged, "usr", "etc")
    etc_dir = os.path.join(merged, "etc")

    if os.path.isdir(usr_etc):
        os.makedirs(etc_dir, exist_ok=True)
        for name in os.listdir(usr_etc):
            src = os.path.join(usr_etc, name)
            dst = os.path.join(etc_dir, name)
            if os.path.isdir(src):
                shutil.copytree(src, dst, symlinks=True, dirs_exist_ok=True)
            else:
                shutil.copy2(src, dst)
        shutil.rmtree(usr_etc)
        print("Merged rootfs: /usretc migrated to /etc", file=sys.stderr)
    else:
        print("Merged rootfs: no /usr/etc present", file=sys.stderr)

    # Remove parent OCI symlinks / directories from merged rootfs
    for d in ("ostree", "sysroot"):
        p = os.path.join(merged, d)
        if os.path.islink(p) or os.path.isfile(p):
            os.unlink(p)
        elif os.path.isdir(p):
            shutil.rmtree(p, ignore_errors=True)

    with open("/merged-path", "w") as f:
        f.write(merged)
    PYEOF

  - |
    cd "%{install-root}"
    build-oci <<EOF
    mode: oci
    gzip: disabled
    images:
    - os: linux
      architecture: "%{go-arch}"
      layer: $(cat /merged-path)
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
