{ pkgs }: {
  name = "tailscaled";
  serviceContent = ''
    [Unit]
    Description=Tailscale node agent
    Documentation=https://tailscale.com/kb/
    Wants=network-pre.target
    After=network-pre.target NetworkManager.service systemd-resolved.service

    [Service]
    EnvironmentFile=-/etc/default/tailscaled
    ExecStartPre=${pkgs.tailscale}/bin/tailscaled --cleanup
    ExecStart=${pkgs.tailscale}/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=''${PORT:-41641}
    ExecStopPost=${pkgs.tailscale}/bin/tailscaled --cleanup
    Restart=on-failure
    RestartSec=5
    KillMode=mixed
    TimeoutStopSec=30
    Type=notify
    User=root
    Group=root

    [Install]
    WantedBy=multi-user.target
  '';
  setupCommands = ''
    echo "Setting up Tailscale service..."
    sudo mkdir -p /var/lib/tailscale /run/tailscale
  '';
}
