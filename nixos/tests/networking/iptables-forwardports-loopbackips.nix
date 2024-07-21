let
  hostIp = "192.168.0.1";
  hostPort = 80;
  containerIp = "192.168.0.100";
  containerPort = 80;
  loopbackIp = "127.0.0.1";
in

import ../make-test-python.nix ({ pkgs, lib, ... }: {
  name = "iptables";

  nodes.machine =
    { pkgs, ... }:
    { imports = [ ../../modules/installer/cd-dvd/channel.nix ];
      virtualisation.writableStore = true;

      containers.webserver =
        { privateNetwork = true;
          hostAddress = hostIp;
          localAddress = containerIp;
          config =
            { services.httpd.enable = true;
              services.httpd.adminAddr = "foo@example.org";
              networking.firewall.allowedTCPPorts = [ 80 ];
            };
        };

      networking.nat = {
        enable = true;
        internalInterfaces = [ "eth0" ];
        externalInterface = "eth0";
        forwardPorts = [
          {
            sourcePort = hostPort;
            proto = "tcp";
            destination = "192.168.100.11:80";
            loopbackIPs = [ loopbackIp ];
          }
        ];
      };

      virtualisation.additionalPaths = [ pkgs.stdenv ];
    };

  testScript =
    ''
      container_list = machine.succeed("nixos-container list")
      assert "webserver" in container_list

      # Start the webserver container.
      machine.succeed("nixos-container start webserver")

      # wait two seconds for the container to start and the network to be up
      machine.sleep(2)

      # Since "start" returns after the container has reached
      # multi-user.target, we should now be able to access it.
      # ip = machine.succeed("nixos-container show-ip webserver").strip()
      machine.succeed("curl --fail http://${loopbackIp}:${toString hostPort}/ > /dev/null")

      # Stop the container.
      machine.succeed("nixos-container stop webserver")
      machine.fail("curl --fail --connect-timeout 2 http://${loopbackIp}:${toString hostPort}/ > /dev/null")

      # Destroying a declarative container should fail.
      machine.fail("nixos-container destroy webserver")
    '';

})
