-- GOALS
-- to be able to write a table to disk that is later loadable,
-- with the complete state restored including metatables

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

local v = vault.write(vault.table("test") {
  this = "is",
  a = "test",
  hello = { 1, 2, 3, 4, 5, 6, 7 },
  position = v3,
})

local f = io.open("test.lua", "w")
if f then
  f:write(v)
  f:close()
end

local t = require("test")(vault)
print(t)
