kind: compose
description: Aurora runtime layer (without devel artifacts)

build-depends:
  - oci/layers/aurora-stack.bst
  - aurora/deps.bst
  - oci/os-release.bst

  # Boot & security infrastructure (from gnomeos, not GNOME-specific)
  - kde-build-meta.bst:gnomeos/fwupd-efi-signed-maybe.bst
  - kde-build-meta.bst:gnomeos/import-deployment-pub-key.bst
  - kde-build-meta.bst:gnomeos/public-keys.bst
  - kde-build-meta.bst:gnomeos/reload-sysext.bst
  - kde-build-meta.bst:gnomeos/replace-signed-systemd-boot.bst
  - kde-build-meta.bst:gnomeos/systemd-pcrlock-workaround.bst

  # Kernel modules & initramfs
  - kde-build-meta.bst:gnomeos/initramfs/signed-modules.bst
  - kde-build-meta.bst:oci/initramfs.bst

  # Essential OCI infrastructure
  - kde-build-meta.bst:oci/integration/bootc-config.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:vm/config/useradd-ostree.bst
  - kde-build-meta.bst:freedesktop-sdk.bst:vm/config/sudo-nopasswd.bst
  - kde-build-meta.bst:oci/integration/lvm2-enable-activation.bst

config:
  exclude:
    - devel
    - debug
    - static-blocklist
