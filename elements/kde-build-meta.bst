kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/91afeca9b70b8aa5581cdacbd85aeda4d5187d25.tar.gz
  ref: 9efa3bdbc5e421dbd1f9ef9fd55fac96bb79d4955d568a398efeeaf15f503731
  base-dir: kde-build-meta-x-91afeca9b70b8aa5581cdacbd85aeda4d5187d25

config:
  options:
    arch: "%{arch}"
