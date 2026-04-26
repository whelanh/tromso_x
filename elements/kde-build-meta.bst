kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/77f6809e5.tar.gz
  ref: 36bacd82ea59fd3ea03604aab37391455a16abdd4adc611b70e7f0819ef17973
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
