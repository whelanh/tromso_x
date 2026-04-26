kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/39c1bb7ab.tar.gz
  ref: 72015ec6ba8a9b5ba5b7c9e5aa10246313bf091725e1437e1ddc410dfca8093b
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
