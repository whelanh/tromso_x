kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/587d152ec4a9ba4755c9deba6d986a40b0fa4d41.tar.gz
  ref: 01fa3ae200fb238c227906a2ceb0e0967544f014eedccc0f3502dad38e212eb2
  base-dir: kde-build-meta-x-587d152ec4a9ba4755c9deba6d986a40b0fa4d41

config:
  options:
    arch: "%{arch}"
