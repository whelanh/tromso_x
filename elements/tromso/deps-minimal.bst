kind: stack
description: Minimal system essentials over KDE Linux base (no Aurora branding)

depends:
  # Core runtime requirements
  - kde-build-meta.bst:freedesktop-sdk.bst:components/dosfstools.bst
  - kde-build-meta.bst:core-deps/dconf.bst
  - kde-build-meta.bst:core-deps/accountsservice.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/ca-certificates.bst
  - tromso/system-config.bst
  - tromso/containers-config.bst
  - tromso/ldconfig-paths.bst

  # Fonts for login manager and desktop text
  - kde-build-meta.bst:kde-linux-deps/noto-fonts.bst
  - kde-build-meta.bst:kde-linux-deps/noto-cjk.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/dejavu-fonts.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/liberation-fonts.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:components/noto-emoji.bst
  - tromso/kde-linux-noto-fontconfig.bst

  # sudo with preserved setuid
  - tromso/sudo-rs.bst
