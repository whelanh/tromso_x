kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/9f261dd5c.tar.gz
  ref: 5da56341f2690e656840a404f5cdc44f6e8e31651bbffa48a799013e308b2b14
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
