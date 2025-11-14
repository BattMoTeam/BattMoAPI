#############################################################################
# Websocket 
#############################################################################

export start_websocket_server

function handle_websocket(ws::WebSocket)

	client_id = UUIDs.uuid4()
	clients[client_id] = ws
	client_id_str = string(client_id)
	@info "Client connected: $client_id_str"
	WebSockets.send(ws, "UUID: $client_id_str")

	try

		for msg in ws
			if msg === nothing
				break  # Exit the loop if no message is received (end of stream)
			end
			@info "Message recieved"
			parsed_data = JSON.parse(msg);

			if haskey(parsed_data, "task") && parsed_data["task"] == "run_simulation"

				json_input_data = parsed_data["data"]

				@info "start simulation"
				WebSockets.send(ws, "started simulation")

				simulation_thread = @async run_simulation_task(json_input_data, ws);

				wait(WebSockets.send(ws, simulation_thread))


				if !ws.writeclosed
					WebSockets.send(ws, "Simulation finished.")
				end


				WebSockets.close(ws)  # Ensure the WebSocket is closed
			end
		end
	catch e
		println("Error handling WebSocket: ", e)
		println("Stacktrace: ", stacktrace())
		if !ws.writeclosed
			WebSockets.send(ws, "Error handling WebSocket: $(e)")
		end
	finally
		if !ws.writeclosed
			WebSockets.close(ws)
		end
	end

end


function start_websocket_server(ws_port::Int)
	HTTP.WebSockets.listen!("0.0.0.0", ws_port) do ws
		handle_websocket(ws)
	end
end
