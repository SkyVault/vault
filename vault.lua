local fmt = string.format
local gmeta, smeta = getmetatable, setmetatable

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
  T = function(self, name)
    return self.types[name]
  end
}

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

function vault.copy(obj, seen)
	seen = seen or {}
	if type(obj) ~= 'table' then return obj end
	if seen and seen[obj] then return seen[obj] end
	local res = {}
	seen[obj] = res
	for k, v in next, obj do res[vault.copy(k, seen)] = vault.copy(v, seen) end
	return setmetatable(res, getmetatable(obj))
end

local function _is_empty(tbl)
  return next(tbl) == nil
end

local function _write(value, seen, novault, indent)
  local t, str = type(value), ""
  if seen[value] then return seen[value] end

  if t == "boolean" or t == "number" then str = tostring(value) end
  if t == "string" then str = fmt("\"%s\"", value) end
  if t == "function" then str = "nil --[["..tostring(value).."]]" end

  if t == "table" or t == "userdata" or t == "function" then
    seen[value] = str
  end

  if t == "table" then
    if _is_empty(value) then
      str = "{}"
    else
      local builder, keys, i = "{\n", {}, 1
      for k,_ in pairs(value) do
        keys[i] = k
        i = i + 1
      end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      for j = 1, #keys do
        local k = keys[j]
        local v = value[k]
        if seen[v] then
          k = "\"" .. k .. "\""
          builder = builder .. fmt(
            "%s[%s] = %s,%s", indent or "", k,
            "nil --[[ recursive table ]]", j < #keys and "\n" or ""
          )
        else
          if type(v) ~= "function" then
            if type(k) ~= "number" then
              k = "\"" .. k .. "\""
              builder = builder .. fmt(
                "%s[%s] = %s,%s", indent or "", k,
                _write(v, seen, novault, (indent or "") .. "  "),
                j < #keys and "\n" or ""
              )
            else
              if j == 1 then builder = builder .. (indent or "") end
              v = _write(v, seen, novault, (indent or "") .. "  ")
              builder = builder .. v .. (j < #keys and ", " or "")
            end
          end
        end
      end
      builder = builder .. "\n" .. (indent or "  "):sub(3) .. "}"
      str = builder

      if not novault and value["vault:name"] ~= nil then
        str = fmt("vault:T(\"%s\"):new %s", value["vault:name"], builder)
      end
    end
  end

  return str
end

function vault.write(obj)
  return fmt(
  "return function(vault)\n  return %s\nend",
    _write(obj, {}))
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
    return tbl["vault:name"] == name
  end

  function tbl:new(values)
    local c = vault.copy(self)
    local it = vault.ext(c, values or {})
    return setmetatable(it, getmetatable(self))
  end

  return setmetatable(
    tbl,
    vault.ext({
      __tostring = function(self) return _write(self, {}, false) end
    }, vault.extract_metatable(tbl))
  )
end

function vault.table(name)
  if type(name) == "table" then
    return vault.base(name)
  end

  return function(tbl)
    tbl = vault.base(tbl)

    if name then
      tbl["vault:name"] = name
      vault.types[name] = tbl
    end

    return tbl
  end
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
