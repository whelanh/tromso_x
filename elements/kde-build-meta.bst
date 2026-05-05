kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/b4b34ac.tar.gz
  ref: 0591aee376d7c94e5e6bc1bb82b81e7a37caedfda810a9cdd1e76366bd7e3cb3
  base-dir: kde-build-meta-b4b34ace8082fcfff2a6a734aa93781f58c35f55

config:
  options:
    arch: "%{arch}"
