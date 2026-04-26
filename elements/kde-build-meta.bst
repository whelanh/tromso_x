kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/ca47f8b.tar.gz
  ref: f64095fc236e65c3314b70a3a800a652cb1577356d99cb635437491a10e38380
  base-dir: kde-build-meta-ca47f8b8395761f567426aeeaa29050ca0d82e3f

config:
  options:
    arch: "%{arch}"
