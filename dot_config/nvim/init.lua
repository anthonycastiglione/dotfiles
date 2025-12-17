-- disable at the very start of your init.lua for nvim-tree (nvim-tree is intended as a full replacement)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- optionally enable 24-bit colour
vim.opt.termguicolors = true

vim.g.mapleader = "\\" -- Make sure to set `mapleader` before lazy so your mappings are correct
vim.g.maplocalleader = "\\" -- Same for `maplocalleader`

-- Register essential keybindings immediately so they work before which-key loads
vim.keymap.set("n", "<leader>t", "<cmd>Telescope find_files<cr>", { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>aw", "<cmd>Telescope live_grep<cr>", { desc = "Telescope live grep" })

-- Use faster shell for better performance
vim.opt.shell = "/bin/bash"

-- smart case, ignore case, tab settings, highlight search on, incremental search on, autoindent on
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.autoindent = true
vim.opt.number = true
vim.opt.updatetime = 300 -- balanced update timing for gitgutter and diagnostics
vim.api.nvim_command("au BufRead,BufNewFile {Gemfile,Rakefile,Vagrantfile,Thorfile,config.ru,*.thor} set ft=ruby")

-- lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
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
		"sindrets/diffview.nvim",
		event = "VeryLazy",
	},

	{
		"airblade/vim-gitgutter",
		event = "VeryLazy",
	},

	-- Treesitter for syntax highlighting
	{
		"nvim-treesitter/nvim-treesitter",
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
		"williamboman/mason.nvim",
		event = "VeryLazy",
		config = function()
			require("mason").setup({})
		end,
	},

	-- Mason tool installer
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		event = "VeryLazy",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = {
					"basedpyright",
					"elixir-ls",
					"eslint_d",
					"golangci-lint",
					"htmlbeautifier",
					"isort",
					"luacheck",
					"lua-language-server",
					"luaformatter",
					"prettier",
					"rubocop",
					"ruby-lsp",
					"rubyfmt",
					"ruff",
					"ty",
					"shfmt",
					"standardjs",
					"standardrb",
					"stimulus-language-server",
					"stylua",
					"vtsls",
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
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			vim.lsp.config("ruby_lsp", {
				init_options = {
					formatter = "standard",
					linters = { "standard" },
				},
				on_attach = function(_client, bufnr)
					-- Enable autoformat on save
					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = bufnr,
						callback = function()
							vim.lsp.buf.format({ async = false })
						end,
					})
				end,
			})

			vim.lsp.config("html_lsp", {})

			vim.lsp.config("stimulus_ls", {
				cmd = { "stimulus-language-server", "--stdio" },
				filetypes = { "html", "ruby", "eruby", "blade", "php" },
			})
			vim.lsp.config("basedpyright", {
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
			vim.lsp.enable("basedpyright")
			vim.lsp.enable("ruby_lsp")
			vim.lsp.enable("html_lsp")
			vim.lsp.enable("stimulus_ls")
			vim.lsp.enable("lua_ls")

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
						require("luasnip").lsp_expand(args.body)
					end,
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				mapping = cmp.mapping.preset.insert({
					["<C-n>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "c" }),
					["<C-p>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "c" }),
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

	-- LuaSnip for snippets
	{
		"L3MON4D3/LuaSnip",
		event = "InsertEnter",
		config = function()
			require("luasnip.loaders.from_vscode").lazy_load()
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
		event = "VeryLazy",
		dependencies = { "nvim-lua/plenary.nvim" },
	},

	-- Git blame
	{
		"FabijanZulj/blame.nvim",
		event = "VeryLazy",
		config = function()
			require("blame").setup({})
		end,
	},

	{
		"xTacobaco/cursor-agent.nvim",
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
			"antoinemadec/FixCursorHold.nvim",
			"nvim-neotest/nvim-nio",
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-rspec"),
				},
			})
		end,
	},

	-- Neotest RSpec adapter
	{
		"olimorris/neotest-rspec",
		event = "VeryLazy",
		dependencies = { "nvim-neotest/neotest" },
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
		init = function()
			vim.o.timeout = true
			vim.o.timeoutlen = 300
		end,
		config = function()
			local wk = require("which-key")

			-- Register key mappings with which-key
			wk.add({
				{ "<leader>a", group = "live grep" },
				{ "<leader>aw", "<cmd>Telescope live_grep <cr>", desc = "Live Grep" },
				{ "<leader>aa", "<cmd>BlameToggle<cr>", desc = "Toggle Git Blame" },
				{ "<leader>b", group = "buffer" },
				{ "<leader>be", "<cmd>Telescope buffers<cr>", desc = "Buffer Explorer" },
				{ "<leader>b", group = "diff" },
				{ "<leader>do", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
				{ "<leader>dd", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
				{ "<leader>f", group = "find" },
				{ "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help Tags" },
				{ "<leader>n", group = "nvim-tree-shortcuts, highlight" },
				{ "<leader>nf", "<cmd>NvimTreeFindFile<cr>", desc = "NvimTreeFindFile" },
				{ "<leader>nh", "<cmd>nohlsearch<cr>", desc = "nohlsearch" },
				{ "<leader>nt", "<cmd>NvimTreeToggle<cr>", desc = "NvimTree" },
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
						local neotest = require("neotest")
						neotest.run.stop()
					end,
					desc = "Cancel the nearest test",
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
						local neotest = require("neotest")
						neotest.run.attach()
					end,
					desc = "Attach to debugger",
				},
				{ "<leader>t", "<cmd>Telescope find_files<cr>" },
				{ "<leader>ws", "<cmd>StripWhitespace<cr>", desc = "Strip trailing whitespace" },
			})
		end,
	},

	-- nvim-lint for inline linting
	{
		"mfussenegger/nvim-lint",
		event = "VeryLazy",
		config = function()
			local lint = require("lint")

			lint.linters_by_ft = {
				lua = { "luacheck" },
			}

			-- Run linter on save and when exiting insert mode
			vim.api.nvim_create_autocmd({ "BufWritePost" }, {
				callback = function()
					lint.try_lint()
				end,
			})
		end,
	},

	-- conform.nvim for auto-formatting
	{
		"stevearc/conform.nvim",
		event = "VeryLazy",
		config = function()
			require("conform").setup({
				formatters_by_ft = {
					lua = { "stylua" },
					javascript = { "prettier" },
					python = {
						"ruff_fix",
						"ruff_format",
					},
					html = { "htmlbeautifier" },
					eruby = { "htmlbeautifier" },
				},
				format_on_save = {
					lsp_fallback = true,
					async = false,
					timeout_ms = 500,
				},
			})
		end,
	},

	-- Telescope fuzzy finder
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.8",
		dependencies = { "nvim-lua/plenary.nvim" },
		event = "VeryLazy",
		config = function()
			local telescope = require("telescope")

			telescope.setup({
				defaults = {
					file_ignore_patterns = {
						".git/",
						".elixir_ls",
						"_build",
						"deps",
						".tmp/",
						"node_modules/",
						"vendor/",
					},
					mappings = {
						n = {
							["<C-e>"] = require("telescope.actions").delete_buffer,
						},
						i = {
							["<C-e>"] = require("telescope.actions").delete_buffer,
						},
					},
				},
				pickers = {
					find_files = {
						hidden = true,
						no_ignore = false,
					},
				},
			})
		end,
	},
})
