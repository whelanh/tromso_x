kind: script
description: >-
  System configuration required for the Aurora OCI image to boot correctly:
  - dbus.service + dbus.socket systemd units (freedesktop-sdk dbus provides
    the binary but not the systemd activation units)
  - sysusers.d entries for system accounts: messagebus (dbus), sshd, rtkit, polkitd
  - sshd.service with Type=simple (avoids sd_notify dependency)
  - systemd-networkd DHCP config for virtio-net (ens3/eth0) — REPLACED by NetworkManager
  - sysctl drop-in: disable IPv6 autoconf on non-loopback interfaces
  - unix_chkpwd setuid so KDE screen locker PAM auth works as non-root
  - KDE PAM service configs (kde, kde-fingerprint, kde-smartcard)
  - kscreenlockerrc: screen lock disabled by default (auto-lock off)

build-depends:
- kde-build-meta.bst:freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- kde-build-meta.bst:freedesktop-sdk.bst:components/linux-pam.bst

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
    # System groups required by udev 50-udev-default.rules for device permissions
    g video - -
    g render - -
    g input - -
    g audio - -
    g kvm - -
    g tty 5
    g disk 6
    g cdrom - -
    g dialout - -
    g lp - -
    g tape - -

    # messagebus: required by dbus-daemon (runs as this user)
    u messagebus - "D-Bus Message Daemon" /run/dbus /usr/sbin/nologin

    # sshd: privilege-separation user for OpenSSH
    u sshd - "OpenSSH privilege separation user" /var/empty/sshd /usr/sbin/nologin

    # rtkit: real-time policy daemon
    u rtkit - "RealtimeKit" / /usr/sbin/nologin

    # polkitd: PolicyKit daemon
    u polkitd - "User for polkitd" /etc/polkit-1 /usr/sbin/nologin

    # plasmalogin: Plasma Login Manager greeter account.  The user record is
    # created by the package's /usr/lib/sysusers.d/plasmalogin.conf; here we
    # only add the group memberships the greeter compositor needs for DRM/input.
    m plasmalogin video
    m plasmalogin render
    m plasmalogin input
    EOF

  # ── sshd.service ─────────────────────────────────────────────────────
  # The upstream openssh systemd service uses Type=notify which requires
  # openssh to be compiled with --with-systemd.  freedesktop-sdk's openssh
  # build does not include that flag, so we use Type=simple to avoid
  # a startup timeout that causes systemd to mark the service as failed.
  # ExecStartPre generates any missing host keys (ostree images ship no keys).
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/systemd/system/sshd.service" <<'EOF'
    [Unit]
    Description=OpenSSH Server Daemon
    Documentation=man:sshd(8) man:sshd_config(5)
    After=network.target

    [Service]
    Type=simple
    ExecStartPre=-/usr/bin/ssh-keygen -A
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

  # ── ld.so.conf ───────────────────────────────────────────────────────
  # Without /etc/ld.so.conf, ldconfig ignores /etc/ld.so.conf.d/*.conf
  # and the Qt6 libs in /usr/lib/ are never registered in the linker
  # cache.  Qt6 ships in the KDE Linux parent OCI layer (not this Aurora
  # layer), so the cache must be rebuilt on the merged image at OCI
  # assembly time (see oci/tromso.bst).
  - |
    install -Dm644 /dev/stdin "%{install-root}/etc/ld.so.conf" <<'EOF'
    include /etc/ld.so.conf.d/*.conf
    EOF

  # ── plasmalogin.service drop-in ──────────────────────────────────────
  # KDE Linux is Wayland-native; Xorg is not installed.  plasma-login-manager
  # runs its own Wayland compositor for the greeter, so no CompositorCommand
  # config is required (unlike SDDM).
  # QT_QUICK_BACKEND=software enables the Mesa software rasterizer for the
  # QML greeter UI in virtualised environments (virtio-vga / llvmpipe).
  - |
    install -d "%{install-root}/usr/lib/systemd/system/plasmalogin.service.d"
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/systemd/system/plasmalogin.service.d/debug.conf" <<'EOF'
    [Service]
    Environment=QT_QUICK_BACKEND=software
    Environment=KWIN_COMPOSE=Q
    StandardOutput=journal+console
    StandardError=journal+console
    EOF

  # Enable plasma-login-manager as the default display manager
  - |
    install -d "%{install-root}/usr/lib/systemd/system/graphical.target.wants"
    ln -sf ../plasmalogin.service "%{install-root}/usr/lib/systemd/system/display-manager.service"
    ln -sf ../plasmalogin.service "%{install-root}/usr/lib/systemd/system/graphical.target.wants/plasmalogin.service"

  # ── plasma-login-manager PAM configs ─────────────────────────────────
  # Unlike SDDM, plasma-login-manager installs its PAM files to
  # /usr/lib/pam.d/ (immutable /usr), so they survive bootc deployment and
  # no /etc/pam.d/ duplication workaround is needed here.

  # ── systemd default target ──────────────────────────────────────────
  - |
    ln -sf graphical.target "%{install-root}/usr/lib/systemd/system/default.target"

  # ── PAM sshd config ──────────────────────────────────────────────────
  # Without /etc/pam.d/sshd, sshd falls back to /etc/pam.d/other which
  # includes system-auth; system-auth has pam_deny.so in the auth stack,
  # causing all SSH password and keyboard-interactive auth to fail.
  # This explicit sshd PAM config bypasses that and uses pam_unix directly.
  - |
    install -Dm644 /dev/stdin "%{install-root}/etc/pam.d/sshd" <<'EOF'
    auth       required    pam_env.so
    auth       required    pam_unix.so shadow nullok
    account    required    pam_nologin.so
    account    required    pam_unix.so
    password   required    pam_unix.so shadow nullok
    session    required    pam_loginuid.so
    session    optional    pam_keyinit.so force revoke
    session    required    pam_unix.so
    session    optional    pam_umask.so silent
    -session   optional    pam_systemd.so
    EOF

  # ── sshd_config ──────────────────────────────────────────────────────  # A minimal default sshd_config.  Without this sshd refuses to start.
  # PermitRootLogin is enabled for the initial Aurora image; users should
  # create a regular account and disable root SSH in production.
  - |
    install -Dm644 /dev/stdin "%{install-root}/etc/ssh/sshd_config" <<'EOF'
    # Aurora default sshd configuration
    HostKey /etc/ssh/ssh_host_rsa_key
    HostKey /etc/ssh/ssh_host_ecdsa_key
    HostKey /etc/ssh/ssh_host_ed25519_key

    SyslogFacility AUTHPRIV
    AuthorizedKeysFile .ssh/authorized_keys
    PasswordAuthentication yes
    PermitRootLogin yes
    ChallengeResponseAuthentication no
    GSSAPIAuthentication no
    UsePAM yes
    X11Forwarding no
    PrintMotd no
    AcceptEnv LANG LC_*
    Subsystem sftp /usr/libexec/sftp-server
    EOF

  # ── PAM fallback configs ─────────────────────────────────────────────
  # freedesktop-sdk linux-pam ships factory defaults in
  # /usr/share/factory/etc/pam.d/ but never copies them to /etc/pam.d/.
  # Without /etc/pam.d/other (or /usr/lib/pam.d/other as fallback) every
  # service without its own PAM config fails with "Critical error - abort".
  # PAM reads /usr/lib/pam.d/ as a fallback for per-service configs.
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/pam.d/other" <<'EOF'
    # Default PAM stack for services without their own /etc/pam.d/ entry.
    auth     include system-auth
    account  include system-auth
    password include system-auth
    session  include system-auth
    EOF

  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/pam.d/system-auth" <<'EOF'
    # Shared auth stack used by other, login, su, etc.
    -auth     [success=done authtok_err=bad perm_denied=bad maxtries=bad default=ignore] pam_systemd_home.so
    auth      sufficient pam_unix.so
    auth      required   pam_deny.so

    account   required   pam_nologin.so
    -account  [success=done authtok_expired=bad new_authtok_reqd=bad maxtries=bad acct_expired=bad default=ignore] pam_systemd_home.so
    account   required   pam_unix.so

    -password sufficient pam_systemd_home.so
    password  sufficient pam_unix.so sha512 shadow try_first_pass
    password  required   pam_deny.so

    -session  optional   pam_keyinit.so revoke
    -session  optional   pam_loginuid.so
    -session  optional   pam_systemd_home.so
    -session  optional   pam_systemd.so
    session   required   pam_unix.so
    EOF

  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/pam.d/login" <<'EOF'
    # PAM config for local terminal (agetty/login) sessions.
    auth     optional   pam_faildelay.so  delay=3000000
    auth     include    system-auth
    account  required   pam_nologin.so
    account  include    system-auth
    password include    system-auth
    session  required   pam_loginuid.so
    -session optional   pam_keyinit.so force revoke
    -session optional   pam_systemd.so
    session  include    system-auth
    EOF

  # ── PAM namespace config ─────────────────────────────────────────────
  # pam_namespace.so in the systemd-user PAM stack requires this file.
  # An empty file means "no namespace bindings" which lets user@N.service
  # start cleanly.  Without it, PAM fails and all user sessions break.
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/share/pam/security/namespace.conf" <<'EOF'
    # Aurora: no PAM namespace bindings configured
    EOF

  # ── unix_chkpwd setuid ───────────────────────────────────────────────
  # pam_unix.so calls unix_chkpwd to verify passwords when running as a
  # non-root process (e.g. kscreenlocker_greet runs as the user, not root).
  # Without setuid, unix_chkpwd cannot read /etc/shadow and PAM auth fails.
  # freedesktop-sdk builds linux-pam without setuid on unix_chkpwd; this
  # overlay installs it with 4755 (setuid + rwxr-xr-x) so the screen locker
  # password prompt works correctly.
  - |
    if [ -x /usr/bin/unix_chkpwd ]; then
      install -Dm 4755 /usr/bin/unix_chkpwd "%{install-root}/usr/bin/unix_chkpwd"
    elif [ -x /usr/sbin/unix_chkpwd ]; then
      install -Dm 4755 /usr/sbin/unix_chkpwd "%{install-root}/usr/bin/unix_chkpwd"
    else
      echo "unix_chkpwd not found in /usr/bin or /usr/sbin" >&2
      exit 1
    fi

  # ── KDE PAM service configs ──────────────────────────────────────────
  # kscreenlocker_greet uses three PAM services in order: kde-fingerprint,
  # kde-smartcard, and kde (password fallback).  Without /etc/pam.d/kde
  # the screen locker falls back to /etc/pam.d/other which uses pam_deny.
  - |
    install -Dm644 /dev/stdin "%{install-root}/etc/pam.d/kde" <<'EOF'
    auth     include  system-auth
    account  include  system-auth
    password include  system-auth
    session  include  system-auth
    EOF

  - |
    install -Dm644 /dev/stdin "%{install-root}/etc/pam.d/kde-fingerprint" <<'EOF'
    auth     [success=done ignore=ignore default=die] pam_fprintd.so
    auth     required pam_deny.so
    account  include  system-auth
    password include  system-auth
    session  include  system-auth
    EOF

  - |
    install -Dm644 /dev/stdin "%{install-root}/etc/pam.d/kde-smartcard" <<'EOF'
    auth     [success=done ignore=ignore default=die] pam_pkcs11.so
    auth     required pam_deny.so
    account  include  system-auth
    password include  system-auth
    session  include  system-auth
    EOF

  # ── KDE screen locker default: auto-lock disabled ────────────────────
  # ── kde-settings profile activation ────────────────────────────────────
  # On Fedora, the kde-settings RPM ships /etc/xdg/plasma-workspace/env/env.sh
  # which adds /usr/share/kde-settings/kde-profile/default/xdg to XDG_CONFIG_DIRS,
  # making Plasma read the system-wide kdeglobals, kcm-about-distrorc, ksplashrc
  # etc. that aurora/common ships there.  We don't have that RPM, so we ship the
  # activation script ourselves.
  - |
    install -Dm644 /dev/stdin \
      "%{install-root}/etc/xdg/plasma-workspace/env/kde-settings.sh" <<'EOF'
    # Activate Aurora system-wide KDE defaults profile (mirrors Fedora kde-settings RPM)
    export XDG_CONFIG_DIRS=/usr/share/kde-settings/kde-profile/default/xdg${XDG_CONFIG_DIRS:+:$XDG_CONFIG_DIRS}
    EOF

  # ── KDE default fonts via kde-settings profile ──────────────────────
  # Without a kdeglobals font entry, Qt6/Plasma picks a platform default that
  # may not have glyphs for all panel widget symbols → tofu squares.
  # We set Noto Sans (guaranteed present) for all font roles.
  # The file goes into the kde-settings XDG profile dir activated by
  # kde-settings.sh above.  Format: Qt6 font description string.
  - |
    install -Dm644 /dev/stdin \
      "%{install-root}/usr/share/kde-settings/kde-profile/default/xdg/kdeglobals" <<'EOF'
    [General]
    font=Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
    fixed=Noto Sans Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
    smallestReadableFont=Noto Sans,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
    toolBarFont=Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
    menuFont=Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
    EOF

  # Ship a system-wide default kscreenlockerrc that disables the auto-lock
  # timer.  Users can override this in their own ~/.config/kscreenlockerrc.
  # Without this the screen locks after 5 minutes by default, which breaks
  # first-boot experience since unix_chkpwd requires a known password.
  - |
    install -Dm644 /dev/stdin "%{install-root}/etc/xdg/kscreenlockerrc" <<'EOF'
    [Daemon]
    Autolock=false
    LockOnResume=false
    Timeout=0
    EOF

  # ── Application menu definition ──────────────────────────────────────
  # Without /etc/xdg/menus/applications.menu the KDE application launcher
  # ("All Applications") shows no entries, even though .desktop files exist
  # in /usr/share/applications/ and KRunner (Alt+F2) can launch them.
  # This minimal menu includes every installed application.
  - |
    install -d "%{install-root}/etc/xdg/menus"
    install -Dm644 /dev/stdin "%{install-root}/etc/xdg/menus/applications.menu" <<'EOF'
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Include>
        <All/>
      </Include>
    </Menu>
    EOF

    # Symlink for KDE Plasma 6 XDG_MENU_PREFIX
    ln -s applications.menu "%{install-root}/etc/xdg/menus/plasma-applications.menu"
    ln -s applications.menu "%{install-root}/etc/xdg/menus/kf6-applications.menu"

    install -Dm644 /dev/stdin "%{install-root}/etc/xdg/autostart/aurora-sycoca.desktop" <<'EOF'
    [Desktop Entry]
    Type=Application
    Name=Rebuild KDE sycoca cache
    Exec=/bin/sh -c 'export LANG=C.UTF-8 XDG_DATA_DIRS=/usr/share:/usr/local/share:/usr/share/kservices6; rm -f $HOME/.cache/ksycoca6*; kbuildsycoca6 --noincremental'
    X-KDE-autostart-phase=2
    NoDisplay=true
    EOF

  # ── XDG_DATA_DIRS for all users ───────────────────────────────────
  # Without this environment variable, kbuildsycoca6 cannot find .desktop
  # files, producing an empty sycoca cache even though 140+ apps are
  # installed in /usr/share/applications/.
  # LANG=en_US.UTF-8 ensures locale-aware XML parsing of .desktop files
  # does not fail on UTF-8 content (Qt6 interprets 'C' as ASCII).
  - |
    install -Dm644 /dev/stdin "%{install-root}/etc/environment.d/50-aurora-xdg.conf" <<'EOFX'
    XDG_DATA_DIRS=/usr/share:/usr/local/share
    LANG=en_US.UTF-8
    EOFX

  # ── Mask unused services ────────────────────────────────────────────
  # Masking in /usr/lib is insufficient because freedesktop-sdk layers can
  # overwrite it during OCI layer merging.
  - |
    install -d "%{install-root}/etc/systemd/system"
    # systemd-homed: Aurora does not use LUKS home dirs; fails on early D-Bus race.
    # Mask the service AND its D-Bus activation so accountsservice does not
    # trip over a broken home1 activation during user enumeration.
    ln -sf /dev/null "%{install-root}/etc/systemd/system/systemd-homed.service"
    ln -sf /dev/null "%{install-root}/etc/systemd/system/dbus-org.freedesktop.home1.service"
    # systemd-homed helper services — still enabled via homed.service.wants;
    # without masking they attempt to start and fail, polluting the journal.
    ln -sf /dev/null "%{install-root}/etc/systemd/system/systemd-homed-activate.service"
    ln -sf /dev/null "%{install-root}/etc/systemd/system/systemd-homed-firstboot.service"
    # debug-shell: ttyS1 early root shell — only needed during development
    ln -sf /dev/null "%{install-root}/etc/systemd/system/debug-shell.service"
    # flatpak-preinstall: requires Flatpak infrastructure not present in base image
    ln -sf /dev/null "%{install-root}/etc/systemd/system/flatpak-preinstall.service"

  # ── Flatpak polkit rule for wheel group ───────────────────────────────
  # The default flatpak polkit rules only cover app-install,
  # runtime-install, app-uninstall, runtime-uninstall, and modify-repo.
  # Internal flatpak system-helper operations (Deploy, GetRevokefsFd) are
  # not covered, causing "not allowed for user" errors even for wheel
  # members.  This blanket rule allows all org.freedesktop.Flatpak.*
  # actions for active local wheel users with no password prompt.
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/share/polkit-1/rules.d/99-flatpak-wheel.rules" <<'EOF'
    polkit.addRule(function(action, subject) {
        if (action.id.startsWith("org.freedesktop.Flatpak.") &&
            subject.active == true && subject.local == true &&
            subject.isInGroup("wheel")) {
                return polkit.Result.YES;
        }
        return polkit.Result.NOT_HANDLED;
    });
    EOF

  # ── NetworkManager enable ────────────────────────────────────────────
  # NetworkManager is the standard network manager for Aurora (same as
  # gnome-build-meta / Dakota).  systemd-networkd is explicitly disabled
  # (as in gnome-build-meta's 80-network.preset) to avoid conflicts.
  - |
    install -d "%{install-root}/usr/lib/systemd/system/multi-user.target.wants"
    ln -sf ../NetworkManager.service \
      "%{install-root}/usr/lib/systemd/system/multi-user.target.wants/NetworkManager.service"
    # Disable systemd-networkd so it does not conflict with NetworkManager
    install -d "%{install-root}/etc/systemd/system"
    ln -sf /dev/null "%{install-root}/etc/systemd/system/systemd-networkd.service"
    ln -sf /dev/null "%{install-root}/etc/systemd/system/systemd-networkd.socket"
    ln -sf /dev/null "%{install-root}/etc/systemd/system/systemd-networkd-wait-online.service"

  # ── dconf database directories ───────────────────────────────────────
  # dconf-update.service compiles profile fragments in /etc/dconf/db/*.d/
  # into binary databases.  These directories must exist or dconf exits
  # with an error at boot.
  - |
    install -d "%{install-root}/etc/dconf/db/distro.d"
    install -d "%{install-root}/etc/dconf/db/site.d"

  # ── Accountsservice user cache primer ─────────────────────────────────
  # accountsservice does not auto-cache users from /etc/passwd on first
  # boot; ListCachedUsers returns empty until someone explicitly calls
  # CacheUser.  The greeter uses ListCachedUsers to populate its user
  # list, so without cached users nobody can log in via the GUI.
  # This oneshot service caches every non-system user before the display
  # manager starts.
  - |
    install -Dm644 /dev/stdin "%{install-root}/usr/lib/systemd/system/aurora-cache-users.service" <<'EOF'
    [Unit]
    Description=Cache non-system users for accountsservice
    DefaultDependencies=no
    After=accounts-daemon.service
    Before=display-manager.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/bin/sh -c 'for u in $$(awk -F: "$$3>=1000&&$$3<65534{print $$1}" /etc/passwd); do busctl --system call org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts CacheUser s "$$u" 2>/dev/null; done'

    [Install]
    WantedBy=graphical.target
    EOF
    install -d "%{install-root}/usr/lib/systemd/system/graphical.target.wants"
    ln -sf ../aurora-cache-users.service "%{install-root}/usr/lib/systemd/system/graphical.target.wants/aurora-cache-users.service"

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
        - '%{sysconfdir}/ssh/sshd_config'
        - '%{sysconfdir}/pam.d/sshd'
        - '%{indep-libdir}/sysusers.d/aurora-system.conf'
        - '%{indep-libdir}/systemd/system/multi-user.target.wants/NetworkManager.service'
        - '%{sysconfdir}/systemd/system/systemd-networkd.service'
        - '%{sysconfdir}/systemd/system/systemd-networkd.socket'
        - '%{sysconfdir}/systemd/system/systemd-networkd-wait-online.service'
        - '%{sysconfdir}/dconf/db/distro.d'
        - '%{sysconfdir}/dconf/db/site.d'
        - '%{indep-libdir}/pam.d/other'
        - '%{indep-libdir}/pam.d/system-auth'
        - '%{indep-libdir}/pam.d/login'
        - '%{datadir}/pam/security/namespace.conf'
        - '%{sysconfdir}/systemd/system/systemd-homed.service'
        - '%{sysconfdir}/systemd/system/dbus-org.freedesktop.home1.service'
        - '%{sysconfdir}/systemd/system/systemd-homed-activate.service'
        - '%{sysconfdir}/systemd/system/systemd-homed-firstboot.service'
        - '%{sysconfdir}/systemd/system/debug-shell.service'
        - '%{sysconfdir}/systemd/system/flatpak-preinstall.service'
        - '%{sysconfdir}/ld.so.conf'
        - '%{indep-libdir}/systemd/system/plasmalogin.service.d/debug.conf'
        - '%{indep-libdir}/systemd/system/display-manager.service'
        - '%{indep-libdir}/systemd/system/graphical.target.wants/plasmalogin.service'
        - '%{indep-libdir}/systemd/system/default.target'
        - '%{bindir}/unix_chkpwd'
        - '%{indep-libdir}/systemd/system/aurora-cache-users.service'
        - '%{indep-libdir}/systemd/system/graphical.target.wants/aurora-cache-users.service'
        - '%{sysconfdir}/pam.d/kde'
        - '%{sysconfdir}/pam.d/kde-fingerprint'
        - '%{sysconfdir}/pam.d/kde-smartcard'
        - '%{sysconfdir}/xdg/kscreenlockerrc'
        - '%{sysconfdir}/xdg/menus/applications.menu'
        - '%{sysconfdir}/xdg/menus/plasma-applications.menu'
        - '%{sysconfdir}/xdg/menus/kf6-applications.menu'
        - '%{sysconfdir}/xdg/autostart/aurora-sycoca.desktop'
        - '%{sysconfdir}/environment.d/50-aurora-xdg.conf'
        - '%{sysconfdir}/xdg/plasma-workspace/env/kde-settings.sh'
        - '%{datadir}/kde-settings/kde-profile/default/xdg/kdeglobals'
        - '%{datadir}/polkit-1/rules.d/99-flatpak-wheel.rules'
