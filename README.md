# Vault

Vault is a simple object system for lua

## Example

```lua
local vault = require("vault")

local v2 = vault.table("v2") {
  x = 0,
  y = 0,
}

print(v2) -- { x = 0, y = 0 }
```
