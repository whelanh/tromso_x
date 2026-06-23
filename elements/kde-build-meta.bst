kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/5e358ad1cafcc0c74508a51bfca2afe0a7b3616d.tar.gz
  ref: e9d975162c5995e0e16c875dab334340c296145c9ef755e143c01caa0bcadf0b
  base-dir: kde-build-meta-x-5e358ad1cafcc0c74508a51bfca2afe0a7b3616d

config:
  options:
    arch: "%{arch}"
