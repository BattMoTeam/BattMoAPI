# websocket_server.jl
#
# Robust multi-client WebSocket server.
# - Each client gets a ClientConnection struct
# - Each client has a dedicated send-channel + send-loop to serialize sends
# - Simulation runs in an @async Task stored per-client and is cancelled on disconnect
#


# -----------------------
# Types & global state
# -----------------------

struct ClientConnection
	id::UUID
	ws::WebSocket
	connected_at::Dates.DateTime
	last_activity::Dates.DateTime
	send_channel::Channel{Union{String, Vector{UInt8}, Nothing}}   # push Strings to send; push `nothing` to stop loop
	send_task::Task                                # the task responsible for sending from send_channel
	sim_task::Union{Nothing, Task}                 # running simulation task (if any)
	kpi_task::Union{Nothing, Task}                 # calculating KPIs task (if any)
end

const clients = Dict{UUID, ClientConnection}()
const clients_lock = ReentrantLock()

# -----------------------
# Utilities
# -----------------------

# Register a new client and start its send-loop
function register_client(ws::WebSocket)
	id = uuid4()
	ch = Channel{Union{String, Vector{UInt8}, Nothing}}(32)   # buffer up to 32 outgoing messages
	conn_placeholder = nothing                 # will set after creating task

	# create the send-loop task (reads channel and sends to ws)
	send_t = @async begin
		try
			for msg in ch
				# msg === nothing is sentinel to stop loop
				if msg === nothing
					break
				end
				try
					# if writeclosed, sending will throw; handle exceptions to cleanup
					WebSockets.send(ws, JSON.json(msg))
				catch e
					@warn "Failed sending to client $id: $e"
					# allow outer code to cleanup
					break
				end
			end
		catch e
			@error "Unexpected error in send-loop for client $id: $e"
		finally
			# ensure channel is drained/stopped
			try
				# try to close the websocket if still open
				if !ws.writeclosed
					WebSockets.close(ws)
				end
			catch _
			end
		end
	end

	conn = ClientConnection(id, ws, now(), now(), ch, send_t, nothing)

	lock(clients_lock) do
		clients[id] = conn
	end

	@info "Registered client: $(id)"
	return conn
end

# Unregister and cleanup client: stop send-loop, cancel sim task, remove from dict
function unregister_client(conn::ClientConnection)
	id = conn.id
	@info "Unregistering client: $id"

	# signal the send-loop to stop by pushing `nothing` (if channel still open)
	try
		if isopen(conn.send_channel)
			put!(conn.send_channel, nothing)
		end
	catch e
		@warn "Error signaling send-loop for $id: $e"
	end

	# cancel simulation task if present
	if conn.sim_task !== nothing
		t = conn.sim_task
		try
			# attempt to interrupt the task gracefully
			Base.throwto(t, InterruptException())
			# optionally wait a tiny bit for it to stop
			sleep(0.01)
		catch e
			@warn "Failed to interrupt sim task for $id: $e"
		end
	end

	# remove from global map
	lock(clients_lock) do
		if haskey(clients, id)
			delete!(clients, id)
		end
	end

	@info "Client unregistered: $id"
end


# Safe send: pushes a message (String or Vector{UInt8}) into the client's send-channel
# Returns true if queued successfully, false otherwise.
function safe_send(conn::ClientConnection, msg)::Bool
	try
		if isopen(conn.send_channel)
			put!(conn.send_channel, msg)
			return true
		else
			return false
		end
	catch e
		@warn "safe_send failed for $(conn.id): $e"
		return false
	end
end

# Helper to find client by UUID (string form) — returns ClientConnection or nothing
function get_client_by_uuid_str(uuid_str::String)
	try
		id = UUID(uuid_str)
	catch
		return nothing
	end
	lock(clients_lock) do
		return get(clients, id, nothing)
	end
end


function truncated_error(e; max_lines = 20)
	lines = split(string(e), '\n')
	if length(lines) > max_lines
		return join(vcat(lines[1:max_lines], ["..."]), '\n')
	else
		return string(e)
	end
end


# -----------------------
# WebSocket handler
# -----------------------

function handle_websocket(ws::WebSocket)
	conn = register_client(ws)
	client_id_str = string(conn.id)
	# send client their id
	safe_send(conn, JSON.json(Dict(
		"type" => "client_id",
		"UUID" => "$client_id_str",
	)))

	try
		for raw_msg in ws
			if raw_msg === nothing
				# end-of-stream / closed from client side
				@info "Received nothing from client $(conn.id); breaking"
				break
			end

			# Update last activity timestamp
			lock(clients_lock) do
				if haskey(clients, conn.id)
					c = clients[conn.id]
					clients[conn.id] = ClientConnection(c.id, c.ws, c.connected_at, now(), c.send_channel, c.send_task, c.sim_task)
				end
			end

			# Expect JSON messages from client
			parsed = nothing
			try
				parsed = JSON.parse(raw_msg)
			catch e
				@warn "Invalid JSON from client $(conn.id): $e"
				safe_send(conn, JSON.json(Dict("type"=>"error", "message"=>"invalid JSON")))
				continue
			end

			# Example message handling:
			# - {"task":"run_simulation", "data": {...}}
			# - {"task":"cancel_simulation"}
			if haskey(parsed, "task") && parsed["task"] == "run_simulation"
				# If a simulation is already running, reject or cancel it first
				if conn.sim_task !== nothing
					safe_send(conn, JSON.json(Dict("type"=>"error", "message"=>"simulation already running")))
				else
					# launch simulation and store Task in client record
					sim_input = get(parsed, "data", Dict())
					t = @async run_simulation_task(sim_input, conn)
					# update client record with sim_task
					lock(clients_lock) do
						if haskey(clients, conn.id)
							c = clients[conn.id]
							clients[conn.id] = ClientConnection(c.id, c.ws, c.connected_at, now(), c.send_channel, c.send_task, t, c.kpi_task)
						end
					end
					safe_send(conn, JSON.json(Dict("type"=>"info", "message"=>"started simulation")))
				end

			elseif haskey(parsed, "task") && parsed["task"] == "cancel_simulation"
				if conn.sim_task !== nothing
					try
						Base.throwto(conn.sim_task, InterruptException())
						safe_send(conn, JSON.json(Dict("type"=>"info", "message"=>"cancelling simulation")))
					catch e
						@warn "Failed to cancel sim for $(conn.id): $e"
						safe_send(conn, JSON.json(Dict("type"=>"error", "message"=>"failed to cancel simulation")))
					end
				else
					safe_send(conn, JSON.json(Dict("type"=>"info", "message"=>"no simulation to cancel")))
				end

			elseif haskey(parsed, "task") && parsed["task"] == "calculate_equilibrium_kpis"
				input = get(parsed, "data", Dict())
				t = @async calculate_equilibrium_kpis_task(input, conn)
				# update client record with sim_task
				lock(clients_lock) do
					if haskey(clients, conn.id)
						c = clients[conn.id]
						clients[conn.id] = ClientConnection(c.id, c.ws, c.connected_at, now(), c.send_channel, c.send_task, c.sim_task, t)
					end
				end
				safe_send(conn, JSON.json(Dict("type"=>"info", "message"=>"calculating equilibrium KPIs")))

			else
				# Unknown message - echo or error
				safe_send(conn, JSON.json(Dict("type"=>"error", "message"=>"unknown task")))
			end
		end
	catch e
		@error "Error in websocket loop for client $(conn.id): $e"
		try
			safe_send(conn, JSON.json(Dict("type"=>"error", "message"=>"internal server error")))
		catch _
		end
	finally
		# final cleanup when connection loop ends or errors occur
		try
			unregister_client(conn)
		catch e
			@warn "Error during unregister_client for $(conn.id): $e"
		end
		@info "Connection handler finished for client $(conn.id)"
	end
end

# -----------------------
# Server start
# -----------------------

function start_websocket_server(ws_port::Int = 8080)
	@info "Starting WebSocket server on 0.0.0.0:$ws_port"
	HTTP.WebSockets.listen!("0.0.0.0", ws_port) do ws
		handle_websocket(ws)
	end
end

# If run as script, start server on default port 8000
if abspath(PROGRAM_FILE) == @__FILE__
	start_websocket_server(8080)
end
