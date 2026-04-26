kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/edbacd24b.tar.gz
  ref: 833529322c952a01eea5dda753086e1dcb7f439a8554c45d555df75aee6f9392
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
