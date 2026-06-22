kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/ab85b07afe7690852bc0e13bcfb4e787ba4e3b02.tar.gz
  ref: 794120797932abc4ca5df7377379e0269749edeb9ceded044577b16890cd6bb5
  base-dir: kde-build-meta-x-ab85b07afe7690852bc0e13bcfb4e787ba4e3b02

config:
  options:
    arch: "%{arch}"
