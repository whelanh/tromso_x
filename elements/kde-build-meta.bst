kind: junction
description: Junction to hanthor/kde-build-meta (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/363c8ba0d7ceb106931c1c569fd5873a3a37008e.tar.gz
  ref: a6d365d089ed4ddd30561614a58d71417a1132a1eafca0beba6c27e0a7ffa535
  base-dir: kde-build-meta-363c8ba0d7ceb106931c1c569fd5873a3a37008e

config:
  options:
    arch: "%{arch}"
