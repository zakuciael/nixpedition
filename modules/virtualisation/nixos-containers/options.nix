{
  virtualisation.nixos-containers.provides.options.nixos =
    { lib, ... }:
    let
      inherit (lib)
        mkDefault
        mkOption
        types
        literalExpression
        ;
    in
    {
      options.nixos-containers = {
        defaultConfig = mkOption {
          description = "A NixOS top-level configuration shared across all containers.";
          default = { };
          visible = "shallow";
          type = types.deferredModule;
        };

        hostAddress = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "10.231.136.1";
          description = ''
            The IPv4 address assigned to the host interface.
          '';
        };

        hostAddress6 = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "fc00::1";
          description = ''
            The IPv6 address assigned to the host interface.
          '';
        };

        containers = mkOption {
          description = ''
            A set of NixOS system configurations to be run as lightweight
            containers.  Each container appears as a service
            `container-«name»`
            on the host system, allowing it to be started and stopped via
            {command}`systemctl`.
          '';
          default = { };
          example = literalExpression ''
            {
              database = {
                config = { config, pkgs, ... }: {
                  services.postgresql.enable = true;
                  services.postgresql.package = pkgs.postgresql_14;

                  system.stateVersion = "${lib.trivial.release}";
                };
              };
            }
          '';
          type = types.attrsOf (
            types.submodule {
              options = {
                config = mkOption {
                  description = "A NixOS top-level configuration of this container.";
                  default = { };
                  visible = "shallow";
                  type = types.deferredModule;
                };

                specialArgs = mkOption {
                  description = ''
                    A set of special arguments to be passed to NixOS modules.
                    This will be merged into the `specialArgs` used to evaluate
                    the containers NixOS configuration.
                  '';
                  default = { };
                  type = types.attrsOf types.unspecified;
                };

                ephemeral = mkOption {
                  description = ''
                    Runs container in ephemeral mode with the empty root filesystem at boot.
                    This way container will be bootstrapped from scratch on each boot
                    and will be cleaned up on shutdown leaving no traces behind.
                    Useful for completely stateless, reproducible containers.

                    Note that this option might require to do some adjustments to the container configuration,
                    e.g. you might want to set
                    {var}`systemd.network.networks.$interface.dhcpV4Config.ClientIdentifier` to "mac"
                    if you use {var}`macvlans` option.
                    This way dhcp client identifier will be stable between the container restarts.

                    Note that the container journal will not be linked to the host if this option is enabled.
                  '';
                  default = false;
                  type = types.bool;
                };

                autoStart = mkOption {
                  description = ''
                    Whether the container is automatically started at boot-time.
                  '';
                  default = false;
                  type = types.bool;
                };

                restartIfChanged = mkOption {
                  description = ''
                    Whether the container should be restarted during a NixOS
                    configuration switch if its definition has changed.
                  '';
                  default = true;
                  type = types.bool;
                };

                timeoutStartSec = mkOption {
                  description = ''
                    Time for the container to start. In case of a timeout,
                    the container processes get killed.
                    See {manpage}`systemd.time(7)`
                    for more information about the format.
                  '';
                  type = types.str;
                  default = "1min";
                };

                extraFlags = mkOption {
                  description = ''
                    Extra flags passed to the systemd-nspawn command.
                    See {manpage}`systemd-nspawn(1)` for details.
                  '';
                  default = [ ];
                  example = [ "--drop-capability=CAP_SYS_CHROOT" ];
                  type = types.listOf types.str;
                };

                privateNetwork = mkOption {
                  description = ''
                    Whether to give the container its own private virtual
                    Ethernet interface.  The interface is called
                    `eth0`, and is hooked up to the interface
                    `ve-«container-name»`
                    on the host.  If this option is not set, then the
                    container shares the network interfaces of the host,
                    and can bind to any port on any interface.
                  '';
                  default = false;
                  type = types.bool;
                };

                privateUsers = mkOption {
                  description = ''
                    Whether to give the container its own private UIDs/GIDs space (user namespacing).
                    Disabled by default (`no`).

                    If set to a number (usually above host's UID/GID range: 65536),
                    user namespacing is enabled and the container UID/GIDs will start at that number.

                    If set to `identity`, mostly equivalent to `0`, this will only provide
                    process capability isolation (no UID/GID isolation, as they are the same as host).

                    If set to `pick`, user namespacing is enabled and the UID/GID range is automatically chosen,
                    so that no overlapping UID/GID ranges are assigned to multiple containers.
                    This is the recommanded option as it enhances container security massively and operates fully automatically in most cases.

                    See <https://www.freedesktop.org/software/systemd/man/latest/systemd-nspawn.html#--private-users=> for details.
                  '';
                  default = "no";
                  type = types.either types.ints.u32 (
                    types.enum [
                      "no"
                      "identity"
                      "pick"
                    ]
                  );
                };

                allowedDevices = mkOption {
                  description = ''
                    A list of device nodes to which the containers has access to.
                  '';
                  default = [ ];
                  example = [
                    {
                      node = "/dev/net/tun";
                      modifier = "rwm";
                    }
                  ];
                  type =
                    with types;
                    listOf (submodule {
                      options = {
                        node = mkOption {
                          example = "/dev/net/tun";
                          type = types.str;
                          description = "Path to device node";
                        };
                        modifier = mkOption {
                          example = "rw";
                          type = types.str;
                          description = ''
                            Device node access modifier. Takes a combination
                            `r` (read), `w` (write), and
                            `m` (mknod). See the
                            {manpage}`systemd.resource-control(5)` man page for more
                            information.'';
                        };
                      };
                    });
                };

                binds = mkOption {
                  description = ''
                    An extra list of directories that is bound to the container.
                  '';
                  default = { };
                  example = literalExpression ''
                    {
                      "/home" = {
                        hostPath = "/home/alice";
                        isReadOnly = false;
                      };
                    }
                  '';
                  type =
                    with types;
                    attrsOf (
                      submodule (
                        { name, ... }:
                        {
                          options = {
                            mountPoint = mkOption {
                              example = "/mnt/usb";
                              type = types.str;
                              description = "Mount point on the container file system.";
                            };
                            hostPath = mkOption {
                              default = null;
                              example = "/home/alice";
                              type = types.nullOr types.str;
                              description = "Location of the host path to be mounted.";
                            };
                            type = mkOption {
                              description = ''
                                Determines wheter the bind mount is a file or a directory.
                                By default its set to "directory".
                              '';
                              type = types.enum [
                                "file"
                                "dir"
                                "directory"
                              ];
                              default = "directory";
                            };
                            isReadOnly = mkOption {
                              default = true;
                              type = types.bool;
                              description = "Determine whether the mounted path will be accessed in read-only mode.";
                            };
                            user = mkOption {
                              default = null;
                              description = ''
                                The user to own the bind mount on both the host and container.
                                If the user does not exist on either the host or container, it will
                                be created automatically with the specified name and UID.
                                If set to null, ownership defaults to root.
                              '';
                              type = types.nullOr (
                                types.submodule {
                                  options = {
                                    name = mkOption {
                                      type = types.str;
                                      description = "The username to assign ownership of the bind mount.";
                                    };
                                    uid = mkOption {
                                      type = types.int;
                                      description = ''
                                        The UID of the user. Used to ensure consistent ownership
                                        of the bind mount across host and container boundaries.
                                        If the user is created automatically, it will be assigned
                                        this UID.
                                      '';
                                    };
                                  };
                                }
                              );
                            };
                            group = mkOption {
                              default = null;
                              description = ''
                                The group to own the bind mount on both the host and container.
                                If the group does not exist on either the host or container, it will
                                be created automatically with the specified name and GID.
                                If set to null, ownership defaults to root.
                              '';
                              type = types.nullOr (
                                types.submodule {
                                  options = {
                                    name = mkOption {
                                      type = types.str;
                                      description = "The group name to assign ownership of the bind mount.";
                                    };
                                    gid = mkOption {
                                      type = types.int;
                                      description = ''
                                        The GID of the group. Used to ensure consistent ownership
                                        of the bind mount across host and container boundaries.
                                        If the group is created automatically, it will be assigned
                                        this GID.
                                      '';
                                    };
                                  };
                                }
                              );
                            };
                          };

                          config = {
                            mountPoint = mkDefault name;
                          };
                        }
                      )
                    );
                };

                forwardPorts = mkOption {
                  type = types.listOf (
                    types.submodule {
                      options = {
                        protocol = mkOption {
                          type = types.str;
                          default = "tcp";
                          description = "The protocol specifier for port forwarding between host and container";
                        };
                        hostPort = mkOption {
                          type = types.port;
                          description = "Source port of the external interface on host";
                        };
                        containerPort = mkOption {
                          type = types.nullOr types.port;
                          default = null;
                          description = "Target port of container";
                        };
                      };
                    }
                  );
                  default = [ ];
                  example = [
                    {
                      protocol = "tcp";
                      hostPort = 8080;
                      containerPort = 80;
                    }
                  ];
                  description = ''
                    List of forwarded ports from host to container. Each forwarded port
                    is specified by protocol, hostPort and containerPort. By default,
                    protocol is tcp and hostPort and containerPort are assumed to be
                    the same if containerPort is not explicitly given.
                  '';
                };

                localAddress = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  example = "10.231.136.2";
                  description = ''
                    The IPv4 address assigned to the interface in the container.
                  '';
                };

                localAddress6 = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  example = "fc00::2";
                  description = ''
                    The IPv6 address assigned to the interface in the container.
                  '';
                };
              };
            }

          );
        };
      };
    };
}
