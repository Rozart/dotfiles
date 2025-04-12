return {

  {
    "nvim-telescope/telescope.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "Marskey/telescope-sg",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = (build_cmd ~= "cmake") and "make"
          or "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
        enabled = build_cmd ~= nil,
        config = function(plugin)
          LazyVim.on_load("telescope.nvim", function()
            local ok, err = pcall(require("telescope").load_extension, "fzf")
            if not ok then
              local lib = plugin.dir .. "/build/libfzf." .. (LazyVim.is_win() and "dll" or "so")
              if not vim.uv.fs_stat(lib) then
                LazyVim.warn("`telescope-fzf-native.nvim` not built. Rebuilding...")
                require("lazy").build({ plugins = { plugin }, show = false }):wait(function()
                  LazyVim.info("Rebuilding `telescope-fzf-native.nvim` done.\nPlease restart Neovim.")
                end)
              else
                LazyVim.error("Failed to load `telescope-fzf-native.nvim`:\n" .. err)
              end
            end
          end)
        end,
      },
    },
    opts = {
      extensions = {
        ast_grep = {
          command = {
            "sg",
            "--json=stream",
          },
          grep_open_files = false,
          lang = nil,
        },
      },
      defaults = {
        layout_strategy = "horizontal",
        sorting_strategy = "ascending",
        layout_config = {
          prompt_position = "top",
          horizontal = {
            mirror = false,
          },
          vertical = {
            mirror = true,
          },
        },
      },
    },
  },
  {
    "debugloop/telescope-undo.nvim",
    dependencies = {
      {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
      },
    },
    keys = {
      {
        "<leader>sA",
        "<cmd>Telescope ast_grep<cr>",
        desc = "AST Grep",
      },
      {
        "<leader>fu",
        "<cmd>Telescope undo<cr>",
        desc = "Undo History",
      },
    },
    opts = {
      extensions = {
        undo = {},
      },
    },
    config = function(_, opts)
      require("telescope").setup(opts)
      require("telescope").load_extension("undo")
    end,
  },
}
