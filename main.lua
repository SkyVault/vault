-- GOALS
-- to be able to write a table to disk that is later loadable,
-- with the complete state restored including metatables

local fmt = string.format
local vault = require("vault")

local t = vault.table { banana = "tomato" }

print(t)

local v3 = vault.table("v3", function(self)
  return setmetatable(self, {
    __tostring = function(self)
      return fmt("(%d %d %d)", self.x, self.y, self.z)
    end,
  })
end) {
  x = 10,
  y = 32,
  z = 3
}

local v = vault.write(vault.table("test-save") {
  this = "is",
  a = "test",
  hello = { 1, 2, 3, 4, 5, 6, 7 },
  position = v3,

  empty = {},

  deeply = {
    nested = {
      table = {
        1, 2, "buckle", "my", "shoe"
      }
    }
  }
})

local f = io.open("test-save.lua", "w")
if f then
  f:write(v)
  f:close()
end

local tt = require("test-save")(vault)
print(tt)
