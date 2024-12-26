-- ~/.config/nvim/lua/coding-tracker/init.lua
local M = {}

-- Store the current session data
M.current_session = {
	start_time = nil,
	last_activity = nil,
	file_type = nil,
	is_active = false,
}

-- Configuration
M.config = {
	idle_timeout = 120, -- 2 minutes
	api_endpoint = "http://localhost:3000/api/track",
}

-- Debug wrapper for all functions
local function debug_print(msg)
	vim.notify("CodingTracker: " .. msg, vim.log.levels.INFO)
end

local function get_timestamp()
	return os.time()
end

local function send_to_api(data)
	--- debug_print("Attempting to send data: " .. vim.inspect(data))

	local curl_command = string.format(
		"curl -X POST -H \"Content-Type: application/json\" -d '%s' %s",
		vim.fn.json_encode(data),
		M.config.api_endpoint
	)

	vim.fn.jobstart(curl_command, {
		on_exit = function(_, code)
			if code ~= 0 then
			--- debug_print("Failed to send data!")
			else
				--- debug_print("Successfully sent data!")
			end
		end,
	})
end

function M.start_tracking()
	local current_ft = vim.bo.filetype
	--- debug_print("Starting tracking for filetype: " .. current_ft)

	if current_ft ~= "" then
		M.current_session = {
			start_time = get_timestamp(),
			last_activity = get_timestamp(),
			file_type = current_ft,
			is_active = true,
		}
		--- debug_print("Session started")
	end
end

function M.update_tracking()
	if M.current_session.is_active then
		local current_time = get_timestamp()
		--- debug_print("Updating tracking")

		if (current_time - M.current_session.last_activity) < M.config.idle_timeout then
			M.current_session.last_activity = current_time
			--- debug_print("Activity updated")
		end
	end
end

function M.end_tracking()
	if M.current_session.is_active then
		local end_time = get_timestamp()
		local duration = end_time - M.current_session.start_time

		-- debug_print("Ending session with duration: " .. duration)

		if duration > 5 then
			local data = {
				file_type = M.current_session.file_type,
				start_time = M.current_session.start_time,
				end_time = end_time,
				duration = duration,
			}
			send_to_api(data)
		end

		M.current_session.is_active = false
	end
end

function M.setup(opts)
	--- debug_print("Setting up plugin")
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	local group = vim.api.nvim_create_augroup("CodingTracker", { clear = true })

	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		group = group,
		callback = function()
			--- debug_print("BufEnter triggered")
			M.start_tracking()
		end,
	})

	vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave", "TextChanged" }, {
		group = group,
		callback = function()
			--- debug_print("Activity triggered")
			M.update_tracking()
		end,
	})

	vim.api.nvim_create_autocmd({ "BufLeave", "VimLeavePre" }, {
		group = group,
		callback = function()
			--- debug_print("Leave triggered")
			M.end_tracking()
		end,
	})

	--- debug_print("Plugin setup complete")
end

return M
