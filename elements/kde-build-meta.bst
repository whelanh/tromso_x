kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/876523745.tar.gz
  ref: 3e089741fab2bef6a82d6fef8bf7ec1bf6a43d965b02586e94f35feb7796921e
  base-dir: kde-build-meta-*

config:
  options:
    arch: "%{arch}"
