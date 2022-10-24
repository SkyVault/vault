local fmt = string.format
local gmeta, smeta = getmetatable, setmetatable

local vault = {
  types = {},
  T = function(self, name)
    return self.types[name]
  end
}

function vault.ext(a, b)
  for k, v in pairs(b) do 
    a[k] = v 
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

local function _write(value, seen, novault, indent)
  local t, str = type(value), ""
  if seen[value] then return seen[value] end
  
  if t == "boolean" or t == "number" then str = tostring(value) end
  if t == "string" then str = fmt("\"%s\"", value) end
  if t == "function" then str = "nil --[["..tostring(value).."]]" end

  if t == "table" then
    local builder, keys, i = "{\n", {}, 1
    for k,_ in pairs(value) do 
      keys[i] = k 
      i = i + 1
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for j = 1, #keys do
      local k = keys[j]
      local v = value[k]
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
          builder = builder .. v .. (j < #keys and ", " or "")
        end
      end
    end
    builder = builder .. "\n}"
    str = builder

    if not novault and value["vault:name"] ~= nil then
      str = fmt("vault:T(\"%s\"):new %s", value["vault:name"], builder)
    end
  end

  seen[value] = str

  return str
end

function vault.write(obj)
  return fmt(
  "return function(vault)\n  return %s\nend",
    _write(obj, {}))
end

function vault.table(name, initializer)
  local function fn(tbl, name, initializer)
    if name then
      tbl["vault:name"] = name
      vault.types[name] = tbl
    end

    if initializer then
      tbl["vault:init"] = initializer
    end

    function tbl:new(values)
      local c = vault.copy(self)
      local it, init = vault.ext(c, values or {}), self["vault:init"]
      local m = getmetatable(it)
      it = init and init(it) or it
      local m2 = vault.ext(m, getmetatable(it))
      return setmetatable(it, m2)
    end

    return setmetatable(initializer and initializer(tbl) or tbl, {
      __tostring = function(self)
        return _write(self, {}, true)
      end
    })
  end

  if type(name) == "table" then
    return fn(name, nil, nil)
  end

  return function(tbl)
    return fn(tbl, name, initializer)
  end
end

function vault.initialize(tbl)
  for k, v in pairs(tbl) do
    if type(v) == "table" and v["vault:name"] then
      local init = vault.types[v["vault:name"]]["vault:init"]
      tbl[k] = init(v)
      vault.initialize(v)
    end
  end
  return tbl
end

return vault
