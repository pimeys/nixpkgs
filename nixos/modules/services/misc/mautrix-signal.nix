{ config, pkgs, lib, ... }:

with lib;

let
  dataDir = "/var/lib/mautrix-signal";
  registrationFile = "${dataDir}/signal-registration.yaml";
  cfg = config.services.mautrix-signal;
  settingsFormat = pkgs.formats.json {};
  settingsFileUnsubstituted = settingsFormat.generate "mautrix-signal-config-unsubstituted.json" cfg.settings;
  settingsFile = "${dataDir}/config.json";

in {
  options = {
    services.mautrix-signal = {
      enable = mkEnableOption "Mautrix-Signal, a Matrix-Signal bridge";

      settings = mkOption rec {
        apply = recursiveUpdate default;
        inherit (settingsFormat) type;
        default = {
          signal = {
            socket_path = "/var/run/signald/signald.sock";
            avatar_dir = "${dataDir}/avatars";
            data_dir = "${dataDir}/data";
            outgoing_attachment_dir = "${dataDir}/tmp";
          };

          appservice = rec {
            address = "http://localhost:${toString port}";
            hostname = "0.0.0.0";
            port = 8080;

            database = "sqlite:///${dataDir}/mautrix-signal.db";
            database_opts = {};
          };

          bridge = {
            permissions."*" = "relaybot";
            relaybot.whitelist = [ ];
            double_puppet_server_map = {};
            login_shared_secret_map = {};
          };

          logging = {
            version = 1;

            formatters.precise.format = "[%(levelname)s@%(name)s] %(message)s";

            handlers.console = {
              class = "logging.StreamHandler";
              formatter = "precise";
            };

            loggers = {
              mau.level = "INFO";
              telethon.level = "INFO";
              aiohttp.level = "WARNING";
            };

            # log to console/systemd instead of file
            root = {
              level = "INFO";
              handlers = [ "console" ];
            };
          };
        };

        example = literalExpression ''
          {
            homeserver = {
              address = "http://localhost:8008";
              domain = "public-domain.tld";
            };

            bridge.permissions = {
              "example.com" = "full";
              "@admin:example.com" = "admin";
            };
          }
        '';
        description = ''
          <filename>config.yaml</filename> configuration as a Nix attribute set.
          Configuration options should match those described in
          <link xlink:href="https://github.com/tulir/mautrix-telegram/blob/master/example-config.yaml">
          example-config.yaml</link>.
          </para>

          <para>
          Secret tokens should be specified using <option>environmentFile</option>
          instead of this world-readable attribute set.
        '';
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          File containing environment variables to be passed to the mautrix-telegram service,
          in which secret tokens can be specified securely by defining values for
          <literal>MAUTRIX_SIGNAL_APPSERVICE_AS_TOKEN</literal>,
          <literal>MAUTRIX_SIGNAL_APPSERVICE_HS_TOKEN</literal>,
        '';
      };

      serviceDependencies = mkOption {
        type = with types; listOf str;
        default = [ "signald.service" ];
        defaultText = literalExpression ''
          [ "signald.service" ]
        '';
        description = ''
          List of Systemd services to require and wait for when starting the application service.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.mautrix-signal = {
      description = "Mautrix-Signal, a Matrix-Signal bridge.";

      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ] ++ cfg.serviceDependencies;
      after = [ "network-online.target" ] ++ cfg.serviceDependencies;

      preStart = ''
        [ -f ${settingsFile} ] && rm -f ${settingsFile}
        old_umask=$(umask)
        umask 0177
        ${pkgs.envsubst}/bin/envsubst \
          -o ${settingsFile} \
          -i ${settingsFileUnsubstituted}
        umask $old_umask

        # generate the appservice's registration file if absent
        if [ ! -f '${registrationFile}' ]; then
          ${pkgs.mautrix-signal}/bin/mautrix-signal \
            --generate-registration \
            --base-config='${pkgs.mautrix-signal}/${pkgs.mautrix-signal.pythonModule.sitePackages}/mautrix_signal/example-config.yaml' \
            --config='${settingsFile}' \
            --registration='${registrationFile}'
        fi
      '' + lib.optionalString (pkgs.mautrix-signal ? alembic) ''
        # run automatic database init and migration scripts
        ${pkgs.mautrix-signal.alembic}/bin/alembic -x config='${settingsFile}' upgrade head
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "always";

        ProtectSystem = "strict";
        PrivateTmp = true;
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;

        WorkingDirectory = pkgs.mautrix-signal; # necessary for the database migration scripts to be found
        StateDirectory = baseNameOf dataDir;
        StateDirectoryMode = "0750";
        UMask = 0027;
        EnvironmentFile = cfg.environmentFile;
        JoinNamespaceOf = "signald.service";
        SupplementaryGroups = [ "signald" ];

        ExecStart = ''
          ${pkgs.mautrix-signal}/bin/mautrix-signal \
            --config='${settingsFile}'
        '';
      };

      restartTriggers = [ settingsFileUnsubstituted ];
    };
  };

  meta.maintainers = with maintainers; [ pimeys ];
}
