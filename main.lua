-- GOALS
-- to be able to write a table to disk that is later loadable,
-- with the complete state restored including metatables

local fmt = string.format
local vault = require("vault")

local t = vault.table { banana = "tomato" }

local v3 = vault.table("v3") {
  x = 10,
  y = 32,
  z = 3
}

local a = { a = 69 }
local b = { b = 420 }
a.b = b
b.a = a

local a_random_table = {
  hello = "world",
  [420] = { 1, 2, 3, { four = true } },
}

local res = vault.table("test-save") {
  recursive = { a = a, b = b },

  this = "is",
  a = "test",
  hello = { 1, 2, 3, 4, 5, 6, 7 },
  position = v3,

  empty = {},

  a_random_table = a_random_table,

  deeply = {
    nested = {
      table = {
        1, 2, "buckle", "my", "shoe"
      }
    }
  },
}

local custom_print = vault.table("c") {
  x = 123,
  __tostring = function(self)
    return "X :: " .. self.x
  end
}

res.custom_print = custom_print

local v = vault.write(res)

local f = io.open("testsave.lua", "w")
if f then
  f:write(v)
  f:close()
end

local tt = require("testsave")(vault)
