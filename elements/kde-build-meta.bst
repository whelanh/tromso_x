kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/1cc166f6faf0366f38a4797d53e38ea94cccdd41.tar.gz
  ref: 1c37c81a269d0c985dafa647b910b4511814478cfee663d42e512eff4e704e9a
  base-dir: kde-build-meta-x-1cc166f6faf0366f38a4797d53e38ea94cccdd41

config:
  options:
    arch: "%{arch}"
