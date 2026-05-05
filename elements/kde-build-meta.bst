kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/de2716f.tar.gz
  ref: 2371cd84b264e5712b653db71b63187a6a34bb1a94e7e00dad5c298eb4f59d57
  base-dir: kde-build-meta-de2716fff8adb046e59cca893f678d654483184d

config:
  options:
    arch: "%{arch}"
