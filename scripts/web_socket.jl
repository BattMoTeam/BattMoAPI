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
		if !ws.writeclosed
			for msg in ws
				if msg === nothing
					break  # Exit the loop if no message is received (end of stream)
				end
				data = JSON.parse(msg)

				response = nothing

				if data["type"] == "get_default_sets"
					WebSockets.send(ws, "UUID: $client_id")
					response = @async get_default_sets_from_battmo()
				elseif data["type"] == "get_equilibrium_kpis"
					WebSockets.send(ws, "UUID: $client_id")
					response = @async get_equilibrium_kpis_from_battmo(data["params"])
				elseif data["type"] == "run_simulation"
					WebSockets.send(ws, "UUID: $client_id")
					response = @async run_simulation_task(data["params"], ws)
				else
					response = Dict("error" => "Unknown request type")
				end

			end
		end

	catch e
		@error "Client $client_id disconnected with error: $e"
	finally
		delete!(clients, client_id)
		@info "Client disconnected: $client_id"

		if !ws.writeclosed
			WebSockets.close(ws)
		end
	end
end

# -------------------------
# Start server
# -------------------------

function start_websocket_server(ws_port::Int)
	HTTP.WebSockets.listen!("0.0.0.0", ws_port) do ws
		handle_ws_client(ws)
	end
end


