# socle itself, its folder and its helper (src/md/infrastructure/helper.md): the window runs as the person; the helper
# verbs run as root through pkexec, for an administrator, with polkit's rule.
{
  config,
  lib,
  pkgs,
  socleSelf,
  ...
}: let
  package = config.socle.package;
  exe = "${package}/bin/socle";
in {
  options.socle.package = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = socleSelf.packages.${pkgs.stdenv.hostPlatform.system}.socle or null;
    description = "socle's program; null: none (a server that is managed from elsewhere).";
  };

  config = lib.mkMerge [
    {
      # (the hash of the layers, read by the history: apply.md)
      system.systemBuilderCommands = ''
        printf '%s' '${config.socle.revision}' > $out/socle-revision
      '';
      # (an administrator edits the draft without root; only the switch needs it: configuration.md)
      systemd.tmpfiles.rules = ["d /etc/socle 2775 root wheel -"];
      programs.git = {
        enable = true;
        config.safe.directory = ["/etc/socle"];
      };
      security.polkit.enable = true;
    }
    (lib.mkIf (package != null) {
      environment.systemPackages = [package];
      # pkexec runs `socle helper <verb>` for an administrator, once per five minutes of a password
      environment.etc."polkit-1/actions/software.froment.socle.policy".text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
          "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
        <policyconfig>
          <vendor>Froment Software</vendor>
          <action id="software.froment.socle.apply">
            <description>Apply a version of the system</description>
            <message>socle needs an administrator to change the system</message>
            <icon_name>socle</icon_name>
            <defaults>
              <allow_any>auth_admin</allow_any>
              <allow_inactive>auth_admin</allow_inactive>
              <allow_active>auth_admin_keep</allow_active>
            </defaults>
            <annotate key="org.freedesktop.policykit.exec.path">${exe}</annotate>
            <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
          </action>
        </policyconfig>
      '';
    })
  ];
}
