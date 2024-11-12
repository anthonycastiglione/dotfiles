return {
  "nvim-neotest/neotest",
  -- lazy = true,
  opts = {
    output = { open_on_run = true },
  },
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "olimorris/neotest-rspec",
    "fredrikaverpil/neotest-golang",
    "nvim-neotest/neotest-plenary",
  },
}

