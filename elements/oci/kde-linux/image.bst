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
  # rootfs, then normalize /usr/etc → /etc so bootc sees exactly one.
  # Uses robust_merge() that handles dangling symlinks and type conflicts
  # (dir↔file↔symlink) which cp -a and shutil.copytree both choke on.
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
        """Merge src tree into dst, handling type conflicts robustly."""
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
                        tar.extractall(parent_out)
            else:
                with tarfile.open(blob) as tar:
                    tar.extractall(parent_out)

        # Merge parent content into merged dir, then overlay /layer
        robust_merge(parent_out, merged)
        shutil.rmtree(parent_out)
        robust_merge(layer_src, merged)

    # Normalize /usr/etc → /etc on the merged rootfs
    usr_etc = os.path.join(merged, "usr", "etc")
    etc_dir = os.path.join(merged, "etc")
    if os.path.isdir(usr_etc):
        robust_merge(usr_etc, etc_dir)
        shutil.rmtree(usr_etc)
        print("Merged rootfs: /usretc migrated to /etc", file=sys.stderr)
    else:
        print("Merged rootfs: no /usr/etc present", file=sys.stderr)

    # Remove parent OCI symlinks / directories from merged rootfs
    for d in ("ostree",):
        p = os.path.join(merged, d)
        _remove(p)

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
