kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/876523745.tar.gz
  ref: 86794fc76bb892289451b614637a153732658a78baf086a3a1c3ee8261cfdad3
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
