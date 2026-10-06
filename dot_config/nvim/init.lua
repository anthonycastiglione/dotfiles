-- disable at the very start of your init.lua for nvim-tree (nvim-tree is intended as a full replacement)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.mapleader = "\\" -- Make sure to set `mapleader` before lazy so your mappings are correct
vim.g.maplocalleader = "\\" -- Same for `maplocalleader`

-- Use faster shell for better performance
vim.opt.shell = "/bin/bash"

-- smart case, ignore case, tab settings, line numbers
-- (hlsearch, incsearch, autoindent, timeout and termguicolors are Neovim defaults)
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.number = true
vim.opt.updatetime = 300 -- balanced update timing for gitgutter and diagnostics
vim.opt.timeoutlen = 300

-- Jekyll (Liquid) templates use plain .html, and Neovim's content sniffing calls
-- them htmldjango because the tags overlap. Treat .html as liquid inside a Jekyll
-- project or when it uses Liquid-only tags; otherwise return nil so the built-in
-- html detection runs.
local liquid_only_tags = { assign = true, capture = true, unless = true, render = true, case = true }
vim.filetype.add({
	pattern = {
		[".*%.html"] = function(path, bufnr)
			if vim.fs.root(path, "_config.yml") then
				return "liquid"
			end
			if not bufnr then
				return
			end
			for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 100, false)) do
				for tag in line:gmatch("{%%%-?%s*(%a+)") do
					if liquid_only_tags[tag] then
						return "liquid"
					end
				end
			end
		end,
	},
})

-- lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local out = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
		return
	end
end
vim.opt.rtp:prepend(lazypath)

-- Initialize lazy.nvim
require("lazy").setup({
	-- Nightfox colorscheme
	{
		"EdenEast/nightfox.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd("colorscheme carbonfox")
		end,
	},

	{
		"airblade/vim-gitgutter",
		event = "VeryLazy",
	},

	-- Treesitter for syntax highlighting
	{
		"nvim-treesitter/nvim-treesitter",
		-- The repo's default branch is now `main` (a rewrite with no `configs` module,
		-- requires nvim 0.12). Pin `master` until migrating.
		branch = "master",
		event = "VeryLazy",
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = { "ruby", "lua", "vim", "javascript", "html", "embedded_template" },
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = false,
				},
				auto_install = true,
			})
		end,
	},

	-- Mason for LSP server management
	{
		"mason-org/mason.nvim",
		event = "VeryLazy",
		config = function()
			require("mason").setup({})
		end,
	},

	-- Mason tool installer
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		event = "VeryLazy",
		dependencies = { "mason-org/mason.nvim" },
		config = function()
			require("mason-tool-installer").setup({
				-- Only tools actually wired up below (LSP / nvim-lint / conform)
				ensure_installed = {
					-- LSP servers
					"basedpyright",
					"html-lsp",
					"lua-language-server",
					"ruby-lsp",
					"stimulus-language-server",
					-- linters
					"eslint_d",
					"luacheck",
					"ruff",
					-- formatters
					"htmlbeautifier",
					"prettier",
					"stylua",
				},
				auto_update = true,
				run_on_start = true,
				start_delay = 3000,
			})
		end,
	},

	-- LSP Config
	{
		"neovim/nvim-lspconfig",
		event = "VeryLazy",
		dependencies = { "mason-org/mason.nvim", "hrsh7th/cmp-nvim-lsp" },
		config = function()
			-- Advertise nvim-cmp's completion capabilities (snippets, resolve, etc.) to every server
			vim.lsp.config("*", {
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
			})

			vim.lsp.config("ruby_lsp", {
				init_options = {
					formatter = "standard",
					linters = { "standard" },
				},
			})

			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						runtime = { version = "LuaJIT" },
						workspace = {
							checkThirdParty = false,
							library = { vim.env.VIMRUNTIME },
						},
					},
				},
			})

			vim.lsp.config("basedpyright", {
				root_dir = function(bufnr, on_dir)
					local name = vim.api.nvim_buf_get_name(bufnr)

					-- Skip pseudo-buffers (diffview://, fugitive://, oil://, …). Their names
					-- aren't filesystem paths, so vim.fs.root() walks off into "." and nvim
					-- sends rootUri=file://. — basedpyright can't resolve that, falls back to
					-- its default workspace, and enumerates from / (the >10s warning).
					if name == "" or name:match("^%a[%w+.%-]*://") then
						return -- never calling on_dir means no client is started
					end

					local root = vim.fs.root(bufnr, {
						"pyrightconfig.json",
						"pyproject.toml",
						"setup.py",
						"setup.cfg",
						"requirements.txt",
						"Pipfile",
						".git",
					})

					-- Never let a nil or relative root through; fall back to the file's own
					-- directory (e.g. a scratch .py with no project marker above it).
					if not root or not vim.startswith(root, "/") then
						root = vim.fs.dirname(name)
					end

					on_dir(root)
				end,
				settings = {
					basedpyright = {
						analysis = {
							diagnosticMode = "openFilesOnly",
							typeCheckingMode = "basic",
							useLibraryCodeForTypes = true,
						},
					},
				},
			})

			vim.lsp.enable({ "basedpyright", "ruby_lsp", "html", "stimulus_ls", "lua_ls" })

			-- Explicit LSP keymaps: bypass tagfunc fallback chain so <C-]> and gd
			-- always use textDocument/definition (not workspace/symbol or ctags).
			-- References (grr), rename (grn), code action (gra) and hover (K) are
			-- Neovim 0.11 defaults.
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(ev)
					local opts = { buffer = ev.buf, silent = true, desc = "Go to definition" }

					-- Phlex::Kit generates helper methods (e.g. Table(...)) dynamically at
					-- runtime via const_added hooks — ruby-lsp can't resolve them statically.
					-- In Ruby buffers, detect the pattern (UppercaseName followed by '(') and
					-- fall back to a Telescope file search in app/components instead of
					-- failing silently.
					local function go_to_definition()
						local word = vim.fn.expand("<cword>")
						local line = vim.api.nvim_get_current_line()
						if vim.bo.filetype == "ruby" and word:match("^%u") and line:match(word .. "%s*%(") then
							local snake = word:gsub("(%u)", function(c)
								return "_" .. c:lower()
							end):gsub("^_", "")
							require("telescope.builtin").find_files({
								prompt_title = "Component: " .. word,
								search_dirs = { "app/components" },
								default_text = snake .. ".rb",
							})
						else
							vim.lsp.buf.definition()
						end
					end

					vim.keymap.set("n", "gd", go_to_definition, opts)
					vim.keymap.set("n", "<C-]>", go_to_definition, opts)
				end,
			})

			-- Enable diagnostics
			vim.diagnostic.config({
				virtual_text = true,
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = false,
			})
		end,
	},

	-- nvim-cmp for autocompletion
	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",
		},
		config = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				-- preset.insert already provides <C-n>/<C-p>
				mapping = cmp.mapping.preset.insert({
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						elseif luasnip.locally_jumpable(1) then
							luasnip.jump(1)
						else
							fallback()
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_prev_item()
						elseif luasnip.locally_jumpable(-1) then
							luasnip.jump(-1)
						else
							fallback()
						end
					end, { "i", "s" }),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "buffer" },
					{ name = "path" },
				}),
			})
		end,
	},

	-- nvim-tree file explorer
	{
		"nvim-tree/nvim-tree.lua",
		lazy = false,
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("nvim-tree").setup({
				git = {
					enable = true,
					ignore = false,
				},
			})

			-- Open nvim-tree when nvim is started with a directory argument
			local function open_nvim_tree(data)
				-- buffer is a directory
				local directory = vim.fn.isdirectory(data.file) == 1

				if not directory then
					return
				end

				-- change to the directory
				vim.cmd.cd(data.file)

				-- open the tree
				require("nvim-tree.api").tree.open()
			end

			vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
		end,
	},

	-- Diffview for git diffs
	{
		"sindrets/diffview.nvim",
		cmd = {
			"DiffviewOpen",
			"DiffviewClose",
			"DiffviewToggleFiles",
			"DiffviewFocusFiles",
			"DiffviewRefresh",
			"DiffviewFileHistory",
		},
		dependencies = { "nvim-lua/plenary.nvim" },
	},

	-- Git blame
	{
		"FabijanZulj/blame.nvim",
		cmd = "BlameToggle",
		opts = {},
	},

	{
		"xTacobaco/cursor-agent.nvim",
		event = "VeryLazy",
		config = function()
			vim.keymap.set("n", "<leader>ca", ":CursorAgent<CR>", { desc = "Cursor Agent: Toggle terminal" })
			vim.keymap.set("v", "<leader>ca", ":CursorAgentSelection<CR>", { desc = "Cursor Agent: Send selection" })
			vim.keymap.set("n", "<leader>cA", ":CursorAgentBuffer<CR>", { desc = "Cursor Agent: Send buffer" })
		end,
	},

	-- Neotest for testing
	{
		"nvim-neotest/neotest",
		event = "VeryLazy",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/nvim-nio",
			"olimorris/neotest-rspec",
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-rspec"),
				},
			})
		end,
	},

	-- Strip whitespace
	{
		"ntpeters/vim-better-whitespace",
		event = "VeryLazy",
	},

	-- Mini.icons for icons
	{
		"echasnovski/mini.icons",
		event = "VeryLazy",
		config = function()
			require("mini.icons").setup({})
		end,
	},

	-- Which-key for key mapping help
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		config = function()
			local wk = require("which-key")

			-- Register key mappings with which-key
			-- (<leader>t and <leader>aw are defined as lazy `keys` on the Telescope spec)
			wk.add({
				{ "<leader>a", group = "grep, blame" },
				{ "<leader>aa", "<cmd>BlameToggle<cr>", desc = "Toggle Git Blame" },
				{ "<leader>b", group = "buffer" },
				{ "<leader>be", "<cmd>Telescope buffers<cr>", desc = "Buffer Explorer" },
				{ "<leader>c", group = "cursor agent" },
				{ "<leader>d", group = "diff" },
				{ "<leader>do", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
				{ "<leader>dd", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
				{ "<leader>f", group = "find" },
				{ "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help Tags" },
				{ "<leader>n", group = "nvim-tree-shortcuts, highlight" },
				{ "<leader>nf", "<cmd>NvimTreeFindFile<cr>", desc = "NvimTreeFindFile" },
				{ "<leader>nh", "<cmd>nohlsearch<cr>", desc = "nohlsearch" },
				{ "<leader>nt", "<cmd>NvimTreeToggle<cr>", desc = "NvimTree" },
				{ "<leader>p", group = "sql formatting", mode = "x" },
				{
					-- <C-u> clears the "'<,'>" that Vim auto-inserts when ':' is pressed in
					-- visual mode, so the explicit range below isn't duplicated.
					"<leader>pg",
					":<C-u>'<,'>!pg_format<cr>",
					desc = "Format selected SQL with pg_format",
					mode = "x",
				},
				{ "<leader>r", group = "ruby-related things" },
				{ "<leader>rd", "Odebugger<Esc>", desc = "Insert 'debugger' one line above" },
				{
					"<leader>rt",
					"<cmd>!ctags -R --exclude=vendor --exclude=node_modules<cr>",
					desc = "Re-Tag with ctags",
				},
				{ "<leader>s", group = "test running" },
				{
					"<leader>sc",
					function()
						require("neotest").run.stop()
					end,
					desc = "Stop the running test",
				},
				{
					"<leader>st",
					function()
						local neotest = require("neotest")
						neotest.run.run()
						neotest.summary.open()
						neotest.output_panel.open()
					end,
					desc = "Run the closest test to the cursor",
				},
				{
					"<leader>ss",
					function()
						local neotest = require("neotest")
						neotest.run.run(vim.fn.expand("%"))
						neotest.summary.open()
						neotest.output_panel.open()
					end,
					desc = "Run the tests for the whole file",
				},
				{
					"<leader>sp",
					function()
						local neotest = require("neotest")
						neotest.summary.close()
						neotest.output_panel.close()
					end,
					desc = "Close neotest summary panel and output panel",
				},
				{
					"<leader>sa",
					function()
						require("neotest").run.attach()
					end,
					desc = "Attach to the running test's output",
				},
				{ "<leader>w", group = "whitespace" },
				{ "<leader>ws", "<cmd>StripWhitespace<cr>", desc = "Strip trailing whitespace" },
			})
		end,
	},

	-- nvim-lint for inline linting
	{
		"mfussenegger/nvim-lint",
		event = "VeryLazy",
		dependencies = { "mason-org/mason.nvim" }, -- puts mason's bin dir on PATH first
		config = function()
			local lint = require("lint")

			-- Ruby linting comes from ruby-lsp (standard), so no linter here
			lint.linters_by_ft = {
				lua = { "luacheck" },
				python = { "ruff" },
				javascript = { "eslint_d" },
			}

			-- Run linter on open, on save, and when exiting insert mode
			vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
				group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
				callback = function()
					lint.try_lint()
				end,
			})

			-- Plugin loads after the first buffer is read, so lint it now
			lint.try_lint()
		end,
	},

	-- conform.nvim for auto-formatting
	{
		"stevearc/conform.nvim",
		event = "VeryLazy",
		dependencies = { "mason-org/mason.nvim" }, -- puts mason's bin dir on PATH first
		config = function()
			require("conform").setup({
				formatters_by_ft = {
					lua = { "stylua" },
					javascript = { "prettier" },
					-- Sort imports only; unlike ruff_fix this never deletes unused imports
					python = {
						"ruff_organize_imports",
						"ruff_format",
					},
					html = { "prettier" },
					eruby = { "htmlbeautifier" },
					liquid = { "prettier_liquid" },
				},
				formatters = {
					-- Plugin installed outside mason (it has no package for it):
					--   npm install --prefix ~/.local/share/nvim/prettier-plugins @shopify/prettier-plugin-liquid
					prettier_liquid = {
						inherit = "prettier",
						prepend_args = {
							"--plugin="
								.. vim.fn.stdpath("data")
								.. "/prettier-plugins/node_modules/@shopify/prettier-plugin-liquid/dist/index.js",
							"--parser=liquid-html",
							-- Skip .prettierignore/.gitignore: repos that only prettier their JS
							-- (e.g. empirical_web ignores everything but *.js) would otherwise get
							-- the file echoed back unchanged, with no error.
							"--ignore-path=/dev/null",
						},
					},
				},
				format_on_save = {
					lsp_format = "fallback",
					-- htmlbeautifier and ruby-lsp's first format can exceed 500ms
					timeout_ms = 1000,
				},
			})
		end,
	},

	-- Telescope fuzzy finder
	{
		"nvim-telescope/telescope.nvim",
		branch = "master",
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = "Telescope",
		keys = {
			{ "<leader>t", "<cmd>Telescope find_files<cr>", desc = "Find files" },
			{ "<leader>aw", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
		},
		config = function()
			local telescope = require("telescope")
			local actions = require("telescope.actions")

			-- ripgrep exclusions (gitignore-style globs; a leading "/" anchors to the
			-- project root so e.g. app/views/tags/ isn't hidden by the ctags file rule)
			local rg_excludes = {
				"--glob=!.git/",
				"--glob=!node_modules/",
				"--glob=!vendor/",
				"--glob=!.tmp/",
				"--glob=!/tags",
				"--glob=!/.elixir_ls/",
				"--glob=!/_build/",
				"--glob=!/deps/",
			}

			telescope.setup({
				defaults = {
					vimgrep_arguments = vim.list_extend({
						"rg",
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
						"--smart-case",
					}, rg_excludes),
					mappings = {
						n = {
							["<C-e>"] = actions.delete_buffer,
						},
						i = {
							["<C-e>"] = actions.delete_buffer,
						},
					},
				},
				pickers = {
					find_files = {
						find_command = vim.list_extend({ "rg", "--files", "--hidden" }, rg_excludes),
					},
				},
			})
		end,
	},
})
