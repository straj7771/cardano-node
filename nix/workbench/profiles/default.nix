{ pkgs, lib, cardanoLib
, runCommand
, workbench
##
, stateDir
, profileName
, useCabalRun
, basePort
}:

let
  inherit (workbench) runWorkbenchJqOnly runJq;

  services-config = import ./services-config.nix
    {
      inherit lib workbench;
      inherit stateDir;
      inherit useCabalRun;
      inherit basePort;
    };

  JSON = runWorkbenchJqOnly "profile-${profileName}.json"
                            "profile json ${profileName}";

  value = __fromJSON (__readFile JSON);

  profile =
    rec {
      name = profileName;

      inherit JSON value;

      topology.files =
        runCommand "topology-${profileName}" {}
          "${workbench.workbench}/bin/wb topology make ${JSON} $out";

      node-specs  =
        {
          JSON = runWorkbenchJqOnly "node-specs-${profileName}.json"
                                    "profile node-specs ${JSON}";

          value = __fromJSON (__readFile node-specs.JSON);
        };

      inherit (pkgs.callPackage
               ./node-services.nix
               { inherit runJq services-config profile;
                 baseNodeConfig = cardanoLib.environments.testnet.nodeConfig;
               })
        node-services;

      inherit (pkgs.callPackage
               ./generator-service.nix
               { inherit runJq services-config profile;})
        generator-service;

      inherit (pkgs.callPackage
               ./tracer-service.nix
               { inherit runJq services-config profile;})
        tracer-service;
    };

in profile
