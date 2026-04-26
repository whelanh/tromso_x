kind: junction
description: Junction to local kde-build-meta-local (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: local
  path: kde-build-meta-local

config:
  options:
    arch: "%{arch}"
