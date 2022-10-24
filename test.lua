return function(vault)
  return vault:T("test"):new {
["a"] = "test",
["hello"] = {
  1, 2, 3, 4, 5, 6, 7
},
["position"] = vault:T("v3"):new {
  ["vault:name"] = "v3",
  ["x"] = 10,
  ["y"] = 32,
  ["z"] = 3,
},
["this"] = "is",
["vault:name"] = "test",
}
end