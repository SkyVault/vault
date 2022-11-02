local fmt = string.format
local gmeta, smeta = getmetatable, setmetatable

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

function vault.base(tbl, initializer)
  function tbl:is(name)
    return tbl["vault:name"] == name
  end

  local meta = vault.ext({
    __tostring = function(self)
      return _write(self, {}, true)
    end
  }, getmetatable(tbl) or {})

  if initializer then
    local init_meta = initializer(tbl)
    if not init_meta or type(init_meta) ~= "table" then
      error("Table initializer should return metatable, but got: ", init_meta)
    end
    meta = vault.ext(meta, init_meta)
    tbl["vault:init"] = initializer
  end

  local final = vault.ext(meta, getmetatable(tbl) or {})

  function tbl:new(values)
    local c = vault.copy(self)
    local it, init = vault.ext(c, values or {}), self["vault:init"]
    local m = getmetatable(it)
    it = init and init(it) or it
    local m2 = vault.ext(m, getmetatable(it))
    return setmetatable(it, m2)
  end

  return setmetatable(tbl, final)
end

function vault.table(name, initializer)
  if type(name) == "table" then
    return vault.base(name, initializer)
  end

  return function(tbl)
    tbl = vault.base(tbl, initializer)

    if name then
      tbl["vault:name"] = name
      vault.types[name] = tbl
    end

    return tbl
  end
end

function vault.initialize(tbl)
  for k, v in pairs(tbl) do
    if type(v) == "table" and v["vault:name"] then
      local init = vault.types[v["vault:name"]]["vault:init"]
      tbl[k] = init and init(v) or v
      vault.initialize(v)
    end
  end
  return tbl
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
