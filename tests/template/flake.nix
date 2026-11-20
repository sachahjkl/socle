# A template of socle's (https://socle.froment.software): its values in layer.json, what it is in template.json.
# Start from it in socle's Templates with this repository's address and "#my-desktop".
{
  outputs = _: {
    socleTemplates."my-desktop" = builtins.fromJSON (builtins.readFile ./template.json) // {layer = ./layer.json;};
  };
}
