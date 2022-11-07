return function(vault)
  return vault:T("test-save"):new {
    ["a"] = "test",
    a_random_table = {
      [420] = {
        1, 2, 3, [4] = {
          four = true,
        }
      },
      hello = "world",
    },
    custom_print = vault:T("c"):new {
      ["vault:name"] = "c",
      ["x"] = 123,
    },
    deeply = {
      nested = {
        table = {
          1, 2, [3] = "buckle", [4] = "my", [5] = "shoe"
        },
      },
    },
    empty = {},
    hello = {
      1, 2, 3, 4, 5, 6, 7
    },
    position = vault:T("v3"):new {
      ["vault:name"] = "v3",
      ["x"] = 10,
      ["y"] = 32,
      ["z"] = 3,
    },
    recursive = {
      ["a"] = {
        ["a"] = 69,
        ["b"] = {
          ["a"] = nil,
          ["b"] = 420,
        },
      },
      ["b"] = nil,
    },
    this = "is",
    ["vault:name"] = "test-save",
  }
end