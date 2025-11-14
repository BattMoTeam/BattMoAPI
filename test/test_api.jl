using HTTP
using HTTP.WebSockets
using JSON
using Arrow
using Tables

function handle_message(msg)
	try
		# Try to parse as JSON
		return JSON.parse(String(msg))
	catch
		# If JSON parsing fails, try Arrow
		try
			io = IOBuffer(msg)
			return Arrow.Table(io)
		catch e
			@error "Unknown message format or failed to parse: $e"
			return nothing
		end
	end
end
function test_websocket(url::String)
	println("Connecting to WebSocket at $url ...")

	HTTP.WebSockets.open(url) do ws
		println("Connected!")

		# Send requests
		requests = [
			Dict("type" => "get_default_sets"),
			Dict("type" => "get_equilibrium_kpis", "params" => Dict("voltage" => 3.7, "capacity" => 2.5, "resistance" => 0.05)),
			Dict("type" => "run_simulation", "params" => Dict("voltage" => 3.7, "capacity" => 2.5, "temperature" => 25.0)),
		]

		for req in requests
			println("\n➡️ Sending request: ", req["type"])
			HTTP.WebSockets.send(ws, JSON.json(req))
		end

		# Receive responses
		for msg in ws
			if msg === nothing
				break
			end

			result = handle_message(msg)

			if result isa Arrow.Table
				println("\n✅ Received Arrow-formatted simulation result:")
				for row in result
					println(row)
				end
			elseif result isa Dict
				println("\n✅ Received JSON response:")
				println(result)
			else
				println("\n❌ Received unknown or unparseable message.")
			end
		end

		println("\n✅ All tests completed. Closing connection.")
	end
end

# Run the test
ws_url = "ws://localhost:8080"
test_websocket(ws_url)
