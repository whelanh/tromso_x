kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/0cd5977458ed5dbe3b4b263e60469cc93e08cc04.tar.gz
  ref: 5b1735e05ff0b0ac62804240d6f2fa0acf9c88997393c855d0622eb22cd25418
  base-dir: kde-build-meta-x-0cd5977458ed5dbe3b4b263e60469cc93e08cc04

config:
  options:
    arch: "%{arch}"
