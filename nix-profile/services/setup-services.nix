{ pkgs }:
let
  # Import all service definitions
  tailscaleService = import ./tailscale.nix { inherit pkgs; };

  # List of all services to install
  services = [ tailscaleService ];

  # Generate setup script
  setupScript = pkgs.writeShellScriptBin "setup-services" ''
    echo "Setting up system services..."

    ${pkgs.lib.concatMapStringsSep "\n" (service: ''
      # Setup ${service.name}
      echo "Installing ${service.name} service..."
      sudo tee /etc/systemd/system/${service.name}.service > /dev/null <<'EOF'
      ${service.serviceContent}
      EOF

      ${service.setupCommands}
    '') services}

    echo "Reloading systemd and enabling services..."
    sudo systemctl daemon-reload

    ${pkgs.lib.concatMapStringsSep "\n" (service: ''
      sudo systemctl enable ${service.name}
    '') services}

    echo ""
    echo "Services installed and enabled:"
    ${pkgs.lib.concatMapStringsSep "\n" (service: ''
      echo "  - ${service.name}: sudo systemctl start ${service.name}"
    '') services}

    echo ""
    echo "All services configured successfully!"
  '';

in setupScript
