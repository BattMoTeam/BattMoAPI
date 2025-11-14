using HTTP
using HTTP.WebSockets
using JSON
using HDF5
using Tables
using Dates

###############################################################################
# Robust WebSocket test client
###############################################################################

const MAX_RETRIES = 1
const RECONNECT_DELAY = 2  # seconds
const HDF5_PREVIEW_ROWS = 5


"""
	pretty_preview(table)

Prints a small preview of an HDF5 table.
"""
function pretty_preview(tbl)
	cols = names(tbl)
	println("📊 Columns: ", cols)
	println("📏 Rows: ", nrow(tbl))

	preview_rows = min(nrow(tbl), HDF5_PREVIEW_ROWS)
	if preview_rows > 0
		println("\n🔍 Preview (first $preview_rows rows):")
		for i in 1:preview_rows
			row = NamedTuple{Tuple(cols)}(Tables.row(tbl, i))
			println("  $row")
		end
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

"""
	process_binary_message(msg, expect_hdf5, expected_length)

Process binary messages. If expecting HDF5, it parses it.
"""
function process_binary_message(msg::Vector{UInt8}, expect_hdf5::Bool, expected_length::Int)
	if !expect_hdf5
		@warn "Received binary message but was NOT expecting HDF5 payload"
		return nothing, false, 0
	end

	# Check size
	if length(msg) != expected_length
		@warn "HDF5 payload size mismatch: expected=$expected_length, got=$(length(msg))"
	end

	# Parse HDF5
	try
		# Step 1: Write the raw HDF5 bytes to a temporary file
		tmpfile = tempname() * ".h5"
		open(tmpfile, "w") do f
			write(f, msg)  # msg must come from a valid HDF5 file
		end

		# Step 2: Open the temporary file with HDF5.jl
		data = Dict()
		h5open(tmpfile, "r") do f
			# time_series
			ts = Dict()
			for name in names(f)
				if isa(f[name], HDF5.Dataset)
					ts[name] = read(f[name])
				end
			end
			data["time_series"] = ts

			# states
			if "states" in names(f)
				states = Dict()
				for name in names(f["states"])
					states[name] = read(f["states"][name])
				end
				data["states"] = states
			end

			# metrics
			if "metrics" in names(f)
				metrics = Dict()
				for name in names(f["metrics"])
					metrics[name] = read(f["metrics"][name])
				end
				data["metrics"] = metrics
			end
		end

		# Step 3: Remove the temporary file
		rm(tmpfile; force = true)

		println("\n✅ Successfully parsed HDF5 result!")
		return data, false, 0
	catch e
		@error "Failed to parse HDF5 binary payload: $(truncated_error(e))"
		return nothing, false, 0
	end
end




"""
	send_simulation_request(ws, inputfile)

Send run_simulation request from a JSON file.
"""
function send_simulation_request(ws, inputfile::String)
	println("📨 Sending simulation request using '$inputfile' ...")

	input = open(inputfile, "r") do f
		JSON.parse(read(f, String))
	end

	request = Dict(
		"task" => "run_simulation",
		"data" => input,
	)

	HTTP.WebSockets.send(ws, JSON.json(request))
end


"""
	run_session(url, inputfile)

Runs a full WebSocket session, including message processing.
"""
function run_session(url, inputfile)
	println("\n🔌 Connecting to $url ...")

	HTTP.WebSockets.open(url) do ws
		println("🟢 Connected at $(now())")

		# Step 1: send simulation request
		send_simulation_request(ws, inputfile)

		# State variables
		expect_hdf5 = false
		expected_length = 0
		result_received = false

		# Step 2: receive loop
		for msg in ws
			if msg === nothing
				println("🔴 Server closed the connection.")
				break
			end

			# TEXT MESSAGE
			if isa(msg, String)

				# Detect JSON by leading '{'
				if startswith(msg, "{")
					parsed = JSON.parse(msg)

					if parsed === nothing
						println("📩 Received plain text: $msg")
						continue
					end

					# Process JSON messages
					if parsed["type"] == "progress"
						println("⏳ Progress: $(parsed["step"]) / $(parsed["total"])")

					elseif parsed["type"] == "error"
						println("❌ Server error: $(parsed["error"])")

					elseif parsed["type"] == "result"
						println("📘 Final status: $(parsed["status"])")
						if parsed["status"] == "error"
							println(parsed["error"])
						end

					elseif parsed["type"] == "hdf5"
						println("📦 HDF5 header received. Expecting $(parsed["length"]) bytes…")
						expect_hdf5 = true
						expected_length = parsed["length"]

					else
						println("📩 Received JSON: $parsed")
					end

				else
					# Non-JSON text (like "UUID: XXX")
					println("📄 Received text message: $msg")
				end

				# BINARY MESSAGE (HDF5?)
			elseif isa(msg, AbstractVector{UInt8})
				# Process HDF5 binary payload
				tbl, expect_hdf5_new, expected_length_new =
					process_binary_message(msg, expect_hdf5, expected_length)

				# Update tracking variables
				expect_hdf5 = expect_hdf5_new
				expected_length = expected_length_new

				if tbl !== nothing
					println("\n🎉 HDF5 simulation completed successfully.")
					result_received = true
				else
					@warn "HDF5 payload was invalid or could not be parsed."
				end

				# UNKNOWN MESSAGE TYPE
			else
				println("⚠️ Unknown message type: ", typeof(msg))
			end
		end

		println("🔌 Closing connection ...")
		WebSockets.close(ws)

		if result_received
			println("🎉 All good — result received.")
		else
			println("⚠️ No result received before disconnect.")
		end
	end
end


"""
	test_websocket(url; retries=MAX_RETRIES, inputfile="input_example.json")

Attempts reconnection automatically.
"""
function test_websocket(url::String; retries::Int = MAX_RETRIES, inputfile::String = "input_example.json")
	attempt = 1

	while attempt ≤ retries
		try
			run_session(url, inputfile)
			return  # success, exit
		catch e
			@error "Connection attempt $attempt failed: $e"
			if attempt == retries
				println("❌ All attempts failed.")
				rethrow(e)
			else
				println("🔁 Retrying in $RECONNECT_DELAY seconds...")
				sleep(RECONNECT_DELAY)
				attempt += 1
			end
		end
	end
end


###############################################################################
# Run the client
###############################################################################

ws_url = "ws://localhost:8080"
test_websocket(ws_url)
