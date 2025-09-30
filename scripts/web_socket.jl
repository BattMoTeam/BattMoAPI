#############################################################################
# Websocket 
#############################################################################

# -------------------------
# WebSocket client handler
# -------------------------
function handle_ws_client(ws::HTTP.WebSockets.WebSocket)
	client_id = UUIDs.uuid4()
	clients[client_id] = ws
	@info "Client connected: $client_id"

	try
		while !HTTP.WebSockets.closed(ws)
			msg = String(take!(ws))
			data = JSON.parse(msg)

			response = nothing

			if data["type"] == "get_default_sets"
				response = get_default_sets_for_client()
			elseif data["type"] == "get_equilibrium_kpis"
				response = get_equilibrium_kpis(data["params"])
			elseif data["type"] == "run_simulation"
				response = run_simulation_task(data["params"])
			elseif data["type"] == "plot"
				response = spawn_plot_server(data["params"])
			else
				response = Dict("error" => "Unknown request type")
			end

			HTTP.WebSockets.send(ws, JSON.json(response))
		end
	catch e
		@error "Client $client_id disconnected with error: $e"
	finally
		delete!(clients, client_id)
		@info "Client disconnected: $client_id"
	end
end

# -------------------------
# Start WebSocket server
# -------------------------
function start_websocket_server(port::Int)
	@info "Starting WebSocket server on port $port"
	HTTP.serve(HTTP.Handlers.RequestHandler() do req::HTTP.Request
			HTTP.WebSockets.upgrade(req) do ws
				handle_ws_client(ws)
			end
		end, port = 8081)
end
