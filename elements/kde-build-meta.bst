kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/04b5cf22e.tar.gz
  ref: dbf308a549ba0a7391ac1b922ea013f7ac51dba004663c0617349fe2fbd67042
  base-dir: kde-build-meta-04b5cf22e6db65de2edeb3cf61cff5ebc6b507c6

config:
  options:
    arch: "%{arch}"
