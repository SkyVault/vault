# Vault

Vault is a simple object system for lua

## Example

```lua
local vault = require("vault")

local v2 = vault.table("v2") {
  x = 0,
  y = 0,
}

print(v2:new { x = 32 }) -- { x = 32, y = 0 }
```

## Advanced types

```lua
vault.interface("has-key", "key")

vault.table("namedescr") {
    name = "", description  = "",
}

local info = vault.table("info") {
    implements("has-key"),
    using("namedescr"),

    key = function(self)
        return self.name .. self.description
    end,
}

local location = vault.variant("location") {
  using("namedescr"),
  vault.table("town")  { population = 300, },
  vault.table("castle") { defence = 10.0 }
}

local t = location.town:new { name = "Tilcoultry" }
local c = location.castle:new { name = "Bilmith" }

print(t.name, " ", c.name)

```
