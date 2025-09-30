using HTTP
using HTTP.WebSockets
using JSON
using Logging

# -------------------------
# WebSocket test client
# -------------------------
function test_websocket(url::String)
	println("Connecting to WebSocket at $url ...")

	HTTP.WebSockets.open(url) do ws
		println("Connected!")

		# 1️⃣ Request default sets
		msg1 = Dict("type" => "get_default_sets")
		HTTP.WebSockets.send(ws, JSON.json(msg1))
		resp1 = String(take!(ws))
		println("\nResponse to get_default_sets:\n", resp1)

		# 2️⃣ Request KPIs calculation
		# kpi_params = Dict(
		# 	"voltage" => 3.7,
		# 	"capacity" => 2.5,
		# 	"resistance" => 0.05,
		# )
		# msg2 = Dict("type" => "calculate_kpis", "params" => kpi_params)
		# HTTP.WebSockets.send(ws, JSON.json(msg2))
		# resp2 = String(take!(ws))
		# println("\nResponse to calculate_kpis:\n", resp2)

		# # 3️⃣ Request a simulation (example)
		# sim_params = Dict(
		# 	"voltage" => 3.7,
		# 	"capacity" => 2.5,
		# 	"temperature" => 25.0,
		# )
		# msg3 = Dict("type" => "run_simulation", "params" => sim_params)
		# HTTP.WebSockets.send(ws, JSON.json(msg3))
		# resp3 = String(take!(ws))
		# println("\nResponse to run_simulation:\n", resp3)

		# # 4️⃣ Request plot server spawn
		# plot_params = Dict("plot_type" => "example")
		# msg4 = Dict("type" => "plot", "params" => plot_params)
		# HTTP.WebSockets.send(ws, JSON.json(msg4))
		# resp4 = String(take!(ws))
		# println("\nResponse to plot:\n", resp4)

		println("\nAll test messages sent. Closing connection.")
	end
end

# -------------------------
# Run test
# -------------------------
ws_url = "ws://localhost:8080"
test_websocket(ws_url)
