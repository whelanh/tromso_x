kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/f85b8a9a2.tar.gz
  ref: 2ef6da9f5eb73c50cb9df566ba49368ff43ab7c48a4ef4f15dda33b8889e1b23
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
