kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/eec9dfee7157b44bda71cd974b8a51ef7244d64c.tar.gz
  ref: 7796325f1183e9e784f2f46b3fba4b6bc0fd64e79bed4cc4a4aecc351294d3e3
  base-dir: kde-build-meta-x-eec9dfee7157b44bda71cd974b8a51ef7244d64c

config:
  options:
    arch: "%{arch}"
