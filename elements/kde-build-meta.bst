kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/1642da7c27530e81de2f0dfb225aa7d850e59e6d.tar.gz
  ref: 08b313473b8cc3388530f20f1f1cb7020a7f6fc57ff03f1c7be585f9448af2b3
  base-dir: kde-build-meta-x-1642da7c27530e81de2f0dfb225aa7d850e59e6d

config:
  options:
    arch: "%{arch}"
