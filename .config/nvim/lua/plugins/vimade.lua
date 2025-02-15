return {
     {
          "tadaa/vimade",
          -- default opts (you can partially set these or configure them however you like)
          opts = {
               -- Recipe can be any of 'default', 'minimalist', 'duo', and 'ripple'
               -- Set animate = true to enable animations on any recipe.
               -- See the docs for other config options.
               recipe = { "duo", { animate = false } },
               -- ncmode = 'windows' will fade inactive windows.
               -- ncmode = 'focus' will only fade after you activate the `:VimadeFocus` command.
               ncmode = "windows",
               fadelevel = 0.4, -- any value between 0 and 1. 0 is hidden and 1 is opaque.
               -- Changes the real or theoretical background color. basebg can be used to give
               -- transparent terminals accurating dimming.  See the 'Preparing a transparent terminal'
               -- section in the README.md for more info.
               -- basebg = [23,23,23],
               basebg = "",
               tint = {
                    -- bg = {rgb={0,0,0}, intensity=0.3}, -- adds 30% black to background
                    -- fg = {rgb={0,0,255}, intensity=0.3}, -- adds 30% blue to foreground
                    -- fg = {rgb={120,120,120}, intensity=1}, -- all text will be gray
                    -- sp = {rgb={255,0,0}, intensity=0.5}, -- adds 50% red to special characters
                    -- you can also use functions for tint or any value part in the tint object
                    -- to create window-specific configurations
                    -- see the `Tinting` section of the README for more details.
               },
               -- prevent a window or buffer from being styled. You
               blocklist = {
                    default = {
                         highlights = {
                              laststatus_3 = function(win, active)
                                   -- Global statusline, laststatus=3, is currently disabled as multiple windows take
                                   -- ownership of the StatusLine highlight (see #85).
                                   if vim.go.laststatus == 3 then
                                        -- you can also return tables (e.g. {'StatusLine', 'StatusLineNC'})
                                        return "StatusLine"
                                   end
                              end,
                              -- Prevent ActiveTabs from highlighting.
                              "TabLineSel",
                              "Pmenu",
                              "PmenuSel",
                              "PmenuKind",
                              "PmenuKindSel",
                              "PmenuExtra",
                              "PmenuExtraSel",
                              "PmenuSbar",
                              "PmenuThumb",
                              -- Lua patterns are supported, just put the text between / symbols:
                              -- '/^StatusLine.*/' -- will match any highlight starting with "StatusLine"
                         },
                         buf_opts = { buftype = { "prompt" } },
                         -- buf_name = {'name1','name2', name3'},
                         -- buf_vars = { variable = {'match1', 'match2'} },
                         -- win_opts = { option = {'match1', 'match2' } },
                         -- win_vars = { variable = {'match1', 'match2'} },
                         -- win_type = {'name1','name2', name3'},
                         -- win_config = { variable = {'match1', 'match2'} },
                    },
                    default_block_floats = function(win, active)
                         return win.win_config.relative ~= ""
                                   and (win ~= active or win.buf_opts.buftype == "terminal")
                                   and true
                              or false
                    end,
                    -- any_rule_name1 = {
                    --   buf_opts = {}
                    -- },
                    -- only_behind_float_windows = {
                    --   buf_opts = function(win, current)
                    --     if (win.win_config.relative == '')
                    --       and (current and current.win_config.relative ~= '') then
                    --         return false
                    --     end
                    --     return true
                    --   end
                    -- },
               },
               -- Link connects windows so that they style or unstyle together.
               -- Properties are matched against the active window. Same format as blocklist above
               link = {},
               groupdiff = true, -- links diffs so that they style together
               groupscrollbind = false, -- link scrollbound windows so that they style together.
               -- enable to bind to FocusGained and FocusLost events. This allows fading inactive
               -- tmux panes.
               enablefocusfading = false,
               -- Time in milliseconds before re-checking windows. This is only used when usecursorhold
               -- is set to false.
               checkinterval = 1000,
               -- enables cursorhold event instead of using an async timer.  This may make Vimade
               -- feel more performant in some scenarios. See h:updatetime.
               usecursorhold = false,
               -- when nohlcheck is disabled the highlight tree will always be recomputed. You may
               -- want to disable this if you have a plugin that creates dynamic highlights in
               -- inactive windows. 99% of the time you shouldn't need to change this value.
               nohlcheck = true,
               focus = {
                    providers = {
                         filetypes = {
                              default = {
                                   -- If you use mini.indentscope, snacks.indent, or hlchunk, you can also highlight
                                   -- using the same indent scope!
                                   -- {'snacks', {}},
                                   -- {'mini', {}},
                                   -- {'hlchunk', {}},
                                   {
                                        "treesitter",
                                        {
                                             min_node_size = 2,
                                             min_size = 1,
                                             max_size = 0,
                                             -- exclude types either too large and/or mundane
                                             exclude = {
                                                  "script_file",
                                                  "stream",
                                                  "document",
                                                  "source_file",
                                                  "translation_unit",
                                                  "chunk",
                                                  "module",
                                                  "stylesheet",
                                                  "statement_block",
                                                  "block",
                                                  "pair",
                                                  "program",
                                                  "switch_case",
                                                  "catch_clause",
                                                  "finally_clause",
                                                  "property_signature",
                                                  "dictionary",
                                                  "assignment",
                                                  "expression_statement",
                                                  "compound_statement",
                                             },
                                        },
                                   },
                                   -- if treesitter fails or there isn't a good match, fallback to blanks
                                   -- (similar to limelight)
                                   {
                                        "blanks",
                                        {
                                             min_size = 1,
                                             max_size = "35%",
                                        },
                                   },
                                   -- if blanks fails to find a good match, fallback to static 35%
                                   {
                                        "static",
                                        {
                                             size = "35%",
                                        },
                                   },
                              },
                              -- You can make custom configurations for any filetype.  Here are some examples.
                              -- markdown ={{'blanks', {min_size=0, max_size='50%'}}, {'static', {max_size='50%'}}}
                              -- javascript = {
                              -- -- only use treesitter (no fallbacks)
                              --   {'treesitter', { min_node_size = 2, include = {'if_statement', ...}}},
                              -- },
                              -- typescript = {
                              --   {'treesitter', { min_node_size = 2, exclude = {'if_statement'}}},
                              --   {'static', {size = '35%'}}
                              -- },
                              -- java = {
                              -- -- mini with a fallback to blanks
                              -- {'mini', {min_size = 1, max_size = 20}},
                              -- {'blanks', {min_size = 1, max_size = '100%' }},
                              -- },
                         },
                    },
               },
          },
     },
}
