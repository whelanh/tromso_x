kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/10cd2ccb3.tar.gz
  ref: e45b32cdcd23968d39586e340850df108e086c8bbe64a531a3f3eb7877313010
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
