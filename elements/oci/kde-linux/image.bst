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

  # Merge /layer/usr/etc into /layer/etc if present, then add opaque
  # whiteout so the parent's /usr/etc (if any) is hidden from bootc.
  # bootc extracts parent layers then /layer; the opaque whiteout in
  # /layer/usr/etc/.wh..wh..opq tells the overlay to hide the lower
  # /usrɛtc entirely, avoiding the "Tree contains both /etc and /usr/etc"
  # error during deployment.
  - |
    if [ -d /layer/usr/etc ]; then
      mkdir -p /layer/etc
      cp -a /layer/usr/etc/. /layer/etc/
      rm -rf /layer/usr/etc
    fi
    mkdir -p /layer/usr/etc
    : > /layer/usr/etc/.wh..wh..opq

  # Also migrate parent OCI's /usr/etc (from freedesktop-sdk OSTree
  # convention) to /layer/etc so no bootc-visible config is lost.
  - |
    python3 << 'PYEOF'
    import json, os, sys, shutil, tempfile

    parent = "/parent"
    layer = "/layer"

    if not (os.path.isdir(parent) and os.path.isfile(os.path.join(parent, "index.json"))):
        print("No index.json in parent OCI layout — skipping")
        sys.exit(0)

    try:
        with open(os.path.join(parent, "index.json")) as f:
            index = json.load(f)
    except Exception as e:
        print(f"Cannot read parent index.json: {e}")
        sys.exit(0)

    try:
        mref = index["manifests"][0]["digest"]
        mdigest = mref.replace("sha256:", "")
        with open(os.path.join(parent, "blobs", "sha256", mdigest)) as f:
            manifest = json.load(f)
    except Exception as e:
        print(f"Cannot read parent manifest: {e}")
        sys.exit(0)

    last = manifest["layers"][-1]
    ldigest = last["digest"].replace("sha256:", "")
    blob = os.path.join(parent, "blobs", "sha256", ldigest)

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

    root = tempfile.mkdtemp()
    try:
        if os.path.isdir(blob):
            for name in os.listdir(blob):
                src = os.path.join(blob, name)
                dst = os.path.join(root, name)
                if os.path.isdir(src):
                    shutil.copytree(src, dst, symlinks=True, dirs_exist_ok=True)
                else:
                    shutil.copy2(src, dst)
        else:
            import tarfile, gzip
            mt = last.get("mediaType", "")
            if "gzip" in mt:
                with gzip.open(blob) as gz:
                    with tarfile.open(fileobj=gz) as tar:
                        extract_tar(tar, root)
            else:
                with tarfile.open(blob) as tar:
                    extract_tar(tar, root)

        parent_usr_etc = os.path.join(root, "usr", "etc")
        if os.path.isdir(parent_usr_etc):
            layer_etc = os.path.join(layer, "etc")
            os.makedirs(layer_etc, exist_ok=True)
            for name in os.listdir(parent_usr_etc):
                src = os.path.join(parent_usr_etc, name)
                dst = os.path.join(layer_etc, name)
                if os.path.isdir(src):
                    shutil.copytree(src, dst, symlinks=True, dirs_exist_ok=True)
                else:
                    shutil.copy2(src, dst)
            # Whiteout already created in previous step
            print("Parent /usretc migrated to /layer/etc")
        else:
            print("No /usr/etc in parent; nothing to migrate")
    finally:
        shutil.rmtree(root, ignore_errors=True)
    PYEOF

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
