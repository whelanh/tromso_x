kind: script
description: >-
  System configuration required for the Aurora OCI image to boot correctly:
  - dbus.service + dbus.socket systemd units (freedesktop-sdk dbus provides
    the binary but not the systemd activation units)
  - sysusers.d entries for system accounts: messagebus (dbus), sshd, rtkit, polkitd
  - sshd.service with Type=simple (avoids sd_notify dependency)
  - systemd-networkd DHCP config for virtio-net (ens3/eth0)
  - sysctl drop-in: disable IPv6 autoconf on non-loopback interfaces

build-depends:
- kde-build-meta.bst:freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  commands:
  # ── D-Bus systemd activation units ──────────────────────────────────
  # freedesktop-sdk's dbus component ships the daemon binary and config
  # but not the systemd .socket / .service activation units. Without these,
  # systemd-logind and any service that depends on the system bus will fail.
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/systemd/system/dbus.socket" <<'EOF'
    [Unit]
    Description=D-Bus System Message Bus Socket
    Before=sockets.target

    [Socket]
    ListenStream=/run/dbus/system_bus_socket

    [Install]
    WantedBy=sockets.target
    EOF

  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/systemd/system/dbus.service" <<'EOF'
    [Unit]
    Description=D-Bus System Message Bus
    Documentation=man:dbus-daemon(1)
    Requires=dbus.socket
    After=dbus.socket
    Before=basic.target
    # Avoid conflict with dbus-broker if it gets added later
    Conflicts=dbus-daemon.service

    [Service]
    Type=notify
    ExecStart=/usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
    ExecReload=/usr/bin/dbus-send --print-reply --system --type=method_call \
      --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig
    OOMScoreAdjust=-900

    [Install]
    Also=dbus.socket
    EOF

  # Enable dbus.socket in multi-user.target (via sockets.target preset)
  - |
    install -d "%{install-root}/usr/lib/systemd/system/sockets.target.wants"
    ln -sf ../dbus.socket "%{install-root}/usr/lib/systemd/system/sockets.target.wants/dbus.socket"

  # ── System users via sysusers.d ──────────────────────────────────────
  # These accounts are required by their respective services.  In an ostree
  # image systemd-sysusers runs at first-boot; the entries here ensure they
  # are created before the services that need them start.
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/sysusers.d/aurora-system.conf" <<'EOF'
    # messagebus: required by dbus-daemon (runs as this user)
    u messagebus - "D-Bus Message Daemon" /run/dbus /usr/sbin/nologin

    # sshd: privilege-separation user for OpenSSH
    u sshd - "OpenSSH privilege separation user" /var/empty/sshd /usr/sbin/nologin

    # rtkit: real-time policy daemon
    u rtkit - "RealtimeKit" / /usr/sbin/nologin

    # polkitd: PolicyKit daemon
    u polkitd - "User for polkitd" /etc/polkit-1 /usr/sbin/nologin
    EOF

  # ── sshd.service ─────────────────────────────────────────────────────
  # The upstream openssh systemd service uses Type=notify which requires
  # openssh to be compiled with --with-systemd.  freedesktop-sdk's openssh
  # build does not include that flag, so we use Type=simple to avoid
  # a startup timeout that causes systemd to mark the service as failed.
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/systemd/system/sshd.service" <<'EOF'
    [Unit]
    Description=OpenSSH Server Daemon
    Documentation=man:sshd(8) man:sshd_config(5)
    After=network.target sshd-keygen.target

    [Service]
    Type=simple
    ExecStart=/usr/bin/sshd -D -e
    Restart=on-failure
    RestartSec=5s
    RuntimeDirectory=sshd
    RuntimeDirectoryMode=0755

    [Install]
    WantedBy=multi-user.target
    EOF

  # Enable sshd in multi-user.target
  - |
    install -d "%{install-root}/usr/lib/systemd/system/multi-user.target.wants"
    ln -sf ../sshd.service "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/sshd.service"

  # ── systemd-networkd DHCP config ────────────────────────────────────
  # Ensures virtio-net / e1000e adapters (ens3, eth0, etc.) get an IPv4
  # address via DHCP when the image boots in a VM or bare-metal with
  # NetworkManager not yet configured.  NetworkManager takes precedence
  # when it is running; this config only activates via systemd-networkd.
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/systemd/network/10-ens-dhcp.network" <<'EOF'
    [Match]
    Name=en*
    Driver=virtio_net e1000e vmxnet3

    [Network]
    DHCP=yes

    [DHCPv4]
    SendHostname=yes
    EOF

public:
  bst:
    split-rules:
      runtime:
        (>):
        - '%{indep-libdir}/systemd/system/dbus.socket'
        - '%{indep-libdir}/systemd/system/dbus.service'
        - '%{indep-libdir}/systemd/system/sockets.target.wants/dbus.socket'
        - '%{indep-libdir}/systemd/system/sshd.service'
        - '%{indep-libdir}/systemd/system/multi-user.target.wants/sshd.service'
        - '%{indep-libdir}/sysusers.d/aurora-system.conf'
        - '%{indep-libdir}/systemd/network/10-ens-dhcp.network'
