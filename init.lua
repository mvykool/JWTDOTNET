local M = {}

M.current_session = {
	start_time = nil,
	last_activity = nil,
	file_type = nil,
	is_active = false,
	pending_updates = {},
	last_sync = nil,
}

M.config = {
	idle_timeout = 120,
	api_endpoint = "https://coding-tracking-server-1.onrender.com/api/track",
	min_duration = 5,
	debug = true,
}

local function log_debug(message, data)
	if M.config.debug then
		local debug_msg = string.format("[CodingTracker Debug] %s", message)
		if data then
			debug_msg = debug_msg .. ": " .. vim.inspect(data)
		end
		vim.notify(debug_msg, vim.log.levels.INFO)
	end
end

-- Modified to handle single session
local function send_to_api(session_data)
	---log_debug("Attempting to send session", session_data)

	local curl_command = string.format(
		"curl -v --fail -X POST -H \"Content-Type: application/json\" -d '%s' %s 2>&1",
		vim.fn.json_encode(session_data),
		M.config.api_endpoint
	)

	vim.fn.jobstart(curl_command, {
		on_exit = function(_, code)
			if code == 0 then
				log_debug("Successfully sent tracking data", { status = code })
			else
				log_debug("Failed to send tracking data", { status = code })
				-- Store failed update back in pending_updates
				table.insert(M.current_session.pending_updates, session_data)
				vim.notify("Failed to send tracking data", vim.log.levels.ERROR)
			end
		end,
	})
end

local function process_pending_updates()
	if #M.current_session.pending_updates == 0 then
		return
	end

	---log_debug("Processing pending updates", M.current_session.pending_updates)

	-- Process each session individually
	for _, session in ipairs(M.current_session.pending_updates) do
		send_to_api(session)
	end

	M.current_session.pending_updates = {}
	M.current_session.last_sync = os.time()
end

function M.start_tracking()
	local current_ft = vim.bo.filetype
	if current_ft ~= "" then
		M.current_session = {
			start_time = os.time(),
			last_activity = os.time(),
			file_type = current_ft,
			is_active = true,
			pending_updates = M.current_session.pending_updates or {},
			last_sync = M.current_session.last_sync,
		}
	end
end

function M.end_tracking()
	if M.current_session.is_active then
		local end_time = os.time()
		local duration = end_time - M.current_session.start_time

		if duration > M.config.min_duration then
			local tracking_data = {
				file_type = M.current_session.file_type,
				start_time = M.current_session.start_time,
				end_time = end_time,
				duration = duration,
			}

			table.insert(M.current_session.pending_updates, tracking_data)
			process_pending_updates()
		end

		M.current_session.is_active = false
	end
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	local group = vim.api.nvim_create_augroup("CodingTracker", { clear = true })

	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		group = group,
		callback = M.start_tracking,
	})

	vim.api.nvim_create_autocmd({ "BufLeave", "VimLeavePre" }, {
		group = group,
		callback = M.end_tracking,
	})

	-- Set up periodic sync timer
	local timer = vim.loop.new_timer()
	timer:start(
		300000,
		300000,
		vim.schedule_wrap(function()
			process_pending_updates()
		end)
	)
end

return M
