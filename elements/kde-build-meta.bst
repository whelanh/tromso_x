kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/378745111.tar.gz
  ref: f872baad3712234dfb830b86a0c336b28c5fe6da92aa99e7ca583fd2638846e5
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
