kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/70a08fcd9.tar.gz
  ref: 98a3e69870871bf41bb52b959d3b1b8d6160b58a42454a55e4f1b15bdbfdd1dc
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
