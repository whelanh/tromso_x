kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/65d9ab7.tar.gz
  ref: aba81e43ae0ac77b298d6067f9889f99a9aec0d70e827ba8211733fb92f537e6
  base-dir: kde-build-meta-65d9ab7f1e77761453748f42dc7c60895d8bf340

config:
  options:
    arch: "%{arch}"
