kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/8a2b79aedab5187504e7bccb5cd6972627829fa2.tar.gz
  ref: c8d9fed79fd1917e8690701ffe61de8c59b4194aec178e37db9260df121237f9
  base-dir: kde-build-meta-x-8a2b79aedab5187504e7bccb5cd6972627829fa2

config:
  options:
    arch: "%{arch}"
