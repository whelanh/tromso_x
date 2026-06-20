kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/c8d887d55671744a40c0a5150c7441231d4f738d.tar.gz
  ref: 5a7e3c697261a72fbc8005cfa1d6c48c816258de2f33289a1cf2704b7c66838a
  base-dir: kde-build-meta-x-c8d887d55671744a40c0a5150c7441231d4f738d

config:
  options:
    arch: "%{arch}"
