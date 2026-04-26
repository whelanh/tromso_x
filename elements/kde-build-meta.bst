kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/ab25216da.tar.gz
  ref: 9f6285a7a13f8c4c7603ed1f535a5cbc4f5312f198c2aa2ea18f425d349a04c0
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
