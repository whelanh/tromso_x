kind: junction
description: Junction to hanthor/kde-build-meta (fork of gnome-build-meta with KDE Plasma)

sources:
- kind: tar
  url: github:hanthor/kde-build-meta/archive/c8306c636.tar.gz
  ref: 62b9b01ce5a2885e1929cc6e025a169dcbc716164498a4ea5f8777654d518cab
  base-dir: kde-build-meta-c8306c636e08b8b8f0e073f0bd78c1fb876be34

config:
  options:
    arch: "%{arch}"
