local fmt = string.format
local gmeta, smeta = getmetatable, setmetatable

function string.starts(String, Start)
  return string.sub(String, 1, string.len(Start)) == Start
end

local metemethods = {
  -- Specials
  "__index", "__newindex", "__mode", "__call",
  "__metatable", "__tostring", "__len", "__pairs",
  "__ipairs", "__gc", "__name", "__close",

  -- Mathematic
  "__unm", "__add", "__sub", "__mul", "__div",
  "__idiv", "__mod", "__pow", "__concat",

  -- Bitwise
  "__band", "__bor", "__bxor",
  "__bnot", "__shl", "__shr",

  -- Equivalence
  "__eq", "__lt", "__le",
}

local function is_identifier(s)
  for w in string.gmatch(s, "[A-Za-z|_][A-Za-z|_|0-9]+") do
    if #w == #s then
      return true
    end
  end
  return false
end

assert(is_identifier("Hello"))
assert(is_identifier("hELlo_woRld"))
assert(not is_identifier("hello-world"))
assert(is_identifier("hELlo_2woRld32"))
assert(not is_identifier("2hello-world"))

local function is_meta_key(key)
  for i = 1, #metemethods do
    if metemethods[i] == key then
      return true
    end
  end
  return false
end

local vault = {
  types = {},
  interfaces = {},
  T = function(self, name)
    return self.types[name]
  end,
  meta = {}
}

function vault.interface(name, ...)
  vault.interfaces[name] = { ... }
end

function vault.implements(...)
  return { ["vault:implements"] = { ... }, }
end

function vault.using(...)
  return { ["vault:using"] = { ... }, }
end

function vault.ext(a, b, seen)
  seen = seen or {}
  seen[a] = true

  for k, v in pairs(b) do
    if not seen[v] and type(v) == "table" and type(a[k]) == "table" then
      seen[v] = true
      vault.ext(a[k], v, seen)
    else
      a[k] = v
    end
  end
  return a
end

function vault.ext2(a)
  return function(b)
    return vault.ext(a, b)
  end
end

function vault.copy(obj, seen)
  seen = seen or {}
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local res = {}
  seen[obj] = res
  for k, v in next, obj do res[vault.copy(k, seen)] = vault.copy(v, seen) end
  return setmetatable(res, getmetatable(obj))
end

function vault.shallow_copy(obj)
  local res = {}
  for k, v in next, obj do res[k] = v end
  return setmetatable(res, getmetatable(obj) or {})
end

local function _is_empty(tbl)
  return next(tbl) == nil
end

local function _write(value, seen, novault, indent)
  local t, str = type(value), ""
  if seen[value] then return seen[value] end

  if t == "boolean" or t == "number" then str = tostring(value) end
  if t == "string" then str = fmt("\"%s\"", value) end
  if t == "function" then str = "nil --[[" .. tostring(value) .. "]]" end

  if t == "table" or t == "userdata" or t == "function" then
    seen[value] = str
  end

  if t == "table" then
    if _is_empty(value) then
      str = "{}"
    else
      local builder, keys, i = "{\n", {}, 1

      for k, _ in pairs(value) do
        local skip = false
        if novault and k == "vault:name" then
          skip = true
        end

        if not skip then
          keys[i] = k
        end
        i = i + 1
      end

      table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
      end)

      for j = 1, #keys do
        local k = keys[j]
        local v = value[k]
        if seen[v] then
          k = "\"" .. k .. "\""
          builder = builder .. fmt("%s[%s] = %s,%s", indent or "", k,
                "nil", j < #keys and "\n" or "", novault and "" or " --[[ recursive table ]]"
              )
        else
          if type(v) ~= "function" then
            local id = (indent or "") .. "  "
            if type(k) == "number" then
              if j == 1 then builder = builder .. (indent or "") end
              if k ~= v then builder = builder .. "[" .. k .. "] = " end

              builder = builder .. _write(v, seen, novault, id)

              if k ~= v and type(keys[j + 1]) == "string" then
                builder = builder .. fmt(",%s", j < #keys and "\n" or "")
              else
                builder = builder .. fmt("%s", j < #keys and ", " or "")
              end
            elseif k ~= nil then
              -- TODO: handle non string keys
              if not is_identifier(k) then
                k = "[\"" .. k .. "\"]"
              end

              builder = builder .. (indent or "")

              builder = builder .. fmt(
                    "%s = %s,%s", k,
                    _write(v, seen, novault, id),
                    j < #keys and "\n" or ""
                  )
            end
          end
        end
        ::continue::
      end
      builder = builder .. "\n" .. (indent or " "):sub(3) .. "}"
      str = str .. builder

      if not novault and value["vault:name"] ~= nil then
        str = fmt("vault:T(\"%s\"):new %s", value["vault:name"], builder)
      end
    end
  end

  return str
end

function vault.write(obj, novault)
  local f = novault and "%s" or "return function(vault)\n  return %s\nend"
  return fmt(f,
    _write(obj, {}, novault, "    "))
end

function vault.extract_metatable(tbl)
  local res = {}
  for k, v in pairs(tbl) do
    if is_meta_key(k) then
      res[k] = v
    end
  end
  return res
end

function vault.base(tbl)
  function tbl:is(name)
    return tbl["vault:name"] == name or tbl["vault:base"] == name
  end

  function tbl:new(values)
    return vault.ext(vault.copy(self), values or {})
  end

  function tbl:new_fast(values)
    return vault.ext(vault.shallow_copy(self), values or {})
  end

  return setmetatable(
    tbl,
    vault.ext({
      __tostring = function(self) return _write(self, {}, true, " ") end
    }, vault.extract_metatable(tbl))
  )
end

function vault.table(name)
  if type(name) == "table" then
    return vault.base(name)
  end

  return function(tbl)
    tbl = vault.base(tbl)

    function tbl:implements(...)
      local is = { ... }
      for _, v in ipairs(is) do
        if not vault.meta[self["vault:name"]].implements[v] then
          return false
        end
      end
      return true
    end

    vault.meta[name] = {
      bases = {},
      using = {},
      implements = {},
    }

    local meta = vault.meta[name]

    for i, v in ipairs(tbl) do
      -- handle interfaces
      if type(v) == "table" and v["vault:implements"] then
        local impls = v["vault:implements"]
        for _, inter in ipairs(impls) do
          local interface = vault.interfaces[inter]
          assert(interface, "Vault Error: Unknown interface '" .. tostring(inter) .. "'")
          for _, m in ipairs(interface) do
            assert(
              tbl[m] and type(tbl[m]) == "function",
              string.format("Vault Error: %s does not have method '%s', required by interface '%s'",
                tbl["vault:name"] or "table", m, i
              )
            )
          end

          meta.implements[inter] = inter
        end

        tbl[i] = nil
      end

      -- handle usings
      if type(v) == "table" and v["vault:using"] then
        local using = v["vault:using"]
        for _, u in ipairs(using) do
          local using_table = vault:T(u)
          for k, uv in pairs(using_table) do
            if not string.starts(k, "vault:") and k ~= "new" and k ~= "new_fast" and k ~= "is" then
              tbl[k] = uv
            end
          end

          meta.using[u] = u
        end

        tbl[i] = nil
      end
    end


    if name then
      tbl["vault:name"] = name
      vault.types[name] = tbl
    end

    return tbl
  end
end

-- function vault.variant(name)
--   return function(tbl)
--   end
-- end

function vault.echo(obj)
  if type(obj) == "table" and not obj['vault:name'] then
    obj = vault.base(obj)
  end
  io.write(vault.write(obj, true))
end

function vault.new(name, overrides)
  local t = vault.types[name]
  if t then
    return t:new(overrides)
  end
  error("Undefined type: ", name)
  return nil
end

return vault
