kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/e9efc7339.tar.gz
  ref: 685b4cb991a35b0b83cbde22de0d638365d725b7000c0224a786173c2cc1d34a
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
