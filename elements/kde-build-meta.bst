kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/ae063e95c.tar.gz
  ref: a1fa334ac2850069a0922238703c9827e3bf2196c2269ab521d4d03db6bc2afa
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
