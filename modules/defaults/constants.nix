{ inputs, ... }:
{
  den.schema.host =
    {
      host,
      lib,
      ...
    }:
    let
      inherit (lib) mkOption types;

      constantType =
        with types;
        attrsOf (oneOf [
          str
          int
          bool
          attrs
          list
          constantType
        ]);

      trim =
        s:
        let
          m = builtins.match "[[:space:]]*(.*[^[:space:]])[[:space:]]*" s;
        in
        if m == null then "" else builtins.head m;

      convertValue =
        v:
        if v == "true" then
          true
        else if v == "false" then
          false
        else if builtins.match "^-?[0-9]+$" v != null then
          builtins.fromJSON v
        else if builtins.match "^-?[0-9]+\\.[0-9]+$" v != null then
          builtins.fromJSON v
        else if lib.hasInfix "," v then
          v |> lib.splitString "," |> map trim |> map convertValue
        else
          v;

      toKeyPath =
        path:
        let
          str = toString path;
          afterPerMachine = lib.last (lib.splitString "per-machine/" str);
          withoutValue = lib.removeSuffix "/value" afterPerMachine;
          rawSegments = lib.splitString "/" withoutValue;
        in
        lib.concatMap (seg: lib.splitString "." (lib.removeSuffix "-constants" seg)) rawSegments;
    in
    {
      options.constants = {
        services = mkOption {
          type = types.attrsOf constantType;
        };
      };

      config = {
        constants.services =
          inputs.import-tree (i: i.initFilter (lib.hasSuffix "/value"))
            (i: i.filter (lib.hasInfix host.hostName))
            (i: i.filter (lib.hasInfix "-constants"))
            (
              i:
              i.map (path: lib.setAttrByPath (lib.tail (toKeyPath path)) (convertValue (lib.fileContents path)))
            )
            (i: i.pipeTo (lib.foldl' lib.recursiveUpdate { }))
            ../../vars;
      };
    };
}
