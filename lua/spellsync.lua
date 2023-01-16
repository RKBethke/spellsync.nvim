local M = {}

-- @func warn(msg, name)
-- @param msg: The message to display
-- @param name: The title of the displayed message.
-- Display a warning notification to the user.
local function warn(msg, name)
	vim.notify(msg, vim.log.levels.WARN, { title = name or "init.lua" })
end

-- @func spell_file_exists (spl_fname, sug_fname, dir_list)
-- @param dir_list: A list of directories to search
-- @return (was_found, found_paths)
-- was_found: Boolean representing whether the file was found
-- found_paths: Newline-sepearated string of paths
local function spell_file_exists(spl_fname, sug_fname, dir_list)
	local found_paths = ""
	local was_found = false

	for _, dir in ipairs(dir_list) do
		local spl_path = vim.fn.globpath(dir, spl_fname)
		local sug_path = vim.fn.globpath(dir, sug_fname)
		if spl_path ~= "" and sug_path ~= "" then
			found_paths = found_paths .. "\n" .. dir
			was_found = true
		end
	end
	return was_found, found_paths
end

-- @func get_dir_choices()
-- Get a list of writable spell directories and choices for confirm()
local function get_dir_choices()
	local dir_list = {}
	local dir_choices = "&Cancel"
	local rtp = vim.o.runtimepath

	local dirs = vim.fn.split(vim.fn.globpath(rtp, "spell"), "\n")
	for _, dir in ipairs(dirs) do
		if vim.fn.filewritable(dir) == 2 then
			table.insert(dir_list, dir)
			dir_choices = dir_choices .. "\n&" .. #dir_list
		end
	end
	return dir_list, dir_choices
end

-- @func get_writable_spell_dir()
-- @return The path of a writeable spell directory
-- By default, always uses the $XDG_DATA_HOME/…/site directory.
local function get_writable_spell_dir()
	return vim.fn.stdpath("data") .. "/site/spell"
end

-- @func download(fname)
-- @param fname: The name of the spell file to download
-- @param dir_name: The destination path of the spell file
-- @return Boolean representing download result (success: 1, failure: 0).
-- Downloads a specified spell file to the given directory.
local function download(fname, dir_name)
	print("Downloading " .. fname .. " to: " .. dir_name)
	local file_location = vim.g.spellfile_URL .. "/" .. fname
	local output_file = dir_name .. "/" .. fname

	if string.match(vim.g.spellfile_URL, "^ftp://") then
		-- TODO: Handle ftp server.
		-- local machine = vim.fn.substitute(vim.g.spellfile_URL, "ftp://([^/]*).*", "\1", "")
		-- local dir = vim.fn.substitute(vim.g.spellfile_URL, "ftp://[^/]*/(.*)", "\1", "")
	else
		local command = "curl --progress-bar " .. file_location .. " -o " .. output_file
		print(command)
		return os.execute(command) == 0
	end
end

-- @func parse_args(func)
-- @param args: Either a string of the desired language, or a user command table with the language.
-- Parse arguments for `sync_spell_files` for both autocmd and user command contexts.
local function parse_args(args)
	if type(args) == "string" then
		return args
	elseif type(args) == "table" and args["args"] then
		return args["args"]
	end
	return nil
end

function M.sync_spell_files(args)
	local language = parse_args(args)
	if not language then
		warn("No language provided.")
		return
	end

	if not vim.g.spellfile_URL then
		-- Always use https:// because it's secure.
		-- The certificate is for nluug.nl, thus we can't use the alias ftp.vim.org here.
		vim.g.spellfile_URL = "https://ftp.nluug.nl/pub/vim/runtime/spell"
	end

	local enc = vim.o.encoding
	if enc == "iso-8859-15" then
		enc = "latin1"
	end

	local lang = vim.fn.tolower(language)
	local spl_fname = lang .. "." .. enc .. ".spl"
	local sug_fname = vim.fn.substitute(spl_fname, ".spl$", ".sug", "")

	-- Get a list of possible directories.
	local dir_list, dir_choices = get_dir_choices()

	-- Check if the specified file already exists.
	local was_found, found_paths = spell_file_exists(spl_fname, sug_fname, dir_list)
	if was_found then
		local download_msg = 'Spell files for "'
			.. lang
			.. '" in '
			.. vim.o.encoding
			.. " found in the following directories:"
			.. found_paths
			.. "\nRe-download these files?"
		local ok, response = pcall(vim.fn.confirm, download_msg, "&Yes\n&No", 2)
		if not ok or response ~= 1 then
			return
		end
	else
		local download_msg = 'No spell files for "' .. lang .. '" in ' .. vim.o.encoding .. "\nDownload?"
		local ok, response = pcall(vim.fn.confirm, download_msg, "&Yes\n&No", 2)
		if not ok or response ~= 1 then
			return
		end
	end

	-- Create a spell directory if none already exist.
	if next(dir_list) == nil then
		local dir_to_create = get_writable_spell_dir()
		if dir_to_create == "" then
			warn("No (writable) spell directory found")
			return
		end

		os.execute("mkdir -p " .. dir_to_create)
		if vim.fn.filewritable(dir_to_create) ~= 2 then
			warn("Failed to create: " .. dir_to_create)
			return
		end

		table.insert(dir_list, dir_to_create)
		dir_choices = dir_choices .. "\n&" .. #dir_list
	end

	-- If there are mutliple valid directories, let the user choose between them.
	local dir_choice = 0
	if #dir_list > 1 then
		local dir_msg = "In which directory would you like to write the file?"
		for i = 1, #dir_list do
			dir_msg = dir_msg .. "\n" .. i .. ". " .. dir_list[i]
		end

		local ok
		ok, dir_choice = pcall(vim.fn.confirm, dir_msg, dir_choices)
		dir_choice = dir_choice - 1
		if not ok or dir_choice <= 0 then
			return
		end
	end

	local dir_name = vim.fn.fnameescape(dir_list[dir_choice])

	if not download(spl_fname, dir_name) then
		-- If file is not found, check for ASCII file.
		local ascii_fname = lang .. ".ascii.spl"
		warn("Could not find file, trying " .. ascii_fname .. "...")

		if not download(ascii_fname) then
			warn("Download failed.")
			return
		end
	end

	if not download(sug_fname, dir_name) then
		warn("Download failed.")
		return
	end

	print("Successfully downloaded '" .. lang .. "' spell files...")
end

function M.setup()
	vim.api.nvim_create_autocmd("SpellFileMissing", {
		callback = function()
			M.sync_spell_files(vim.fn.expand("<amatch>"))
		end,
	})

	vim.api.nvim_create_user_command("SpellSync", M.sync_spell_files, { nargs = 1 })
end

return M
