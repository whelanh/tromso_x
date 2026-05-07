kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/27d834e.tar.gz
  ref: 2cfeea030e0fd712cd4a6cbc367905fbeb9444e37751da9611131e8c8f2293ca
  base-dir: kde-build-meta-27d834eeb47de421cc472991bed0a7d893ec6e38

config:
  options:
    arch: "%{arch}"
