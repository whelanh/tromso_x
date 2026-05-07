kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/ccdf7ae.tar.gz
  ref: b6a973574dbedfa5de5af6950cd0b3f2184acf44397a31318aa45471526200ae
  base-dir: kde-build-meta-ccdf7aecfe9ee1362ca008119614190c219de074

config:
  options:
    arch: "%{arch}"
