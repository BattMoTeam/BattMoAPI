# -----------------------
# Run simulation task
# -----------------------
# The important bits:
# - Periodically push progress updates via safe_send(conn, msg)
# - Check for early termination (e.g., client closed) and handle InterruptException
#
function run_simulation_task(sim_input::Dict, conn::ClientConnection)
	try
		@info "Starting simulation for client $(conn.id) with input $(sim_input)"

		# Run simulation
		output = run_simulation(FullSimulationInput(sim_input));
		output_hdf5 = format_output_hdf5(output);  # Vector{UInt8}

		# Update activity
		lock(clients_lock) do
			if haskey(clients, conn.id)
				c = clients[conn.id]
				clients[conn.id] = ClientConnection(
					c.id, c.ws, c.connected_at, now(),
					c.send_channel, c.send_task, c.sim_task,
				)
			end
		end

		# 1) Send header JSON
		header = JSON.json(Dict(
			"type" => "hdf5",
			"format" => "hdf5-ipc-stream",
			"length" => length(output_hdf5),
			"status" => "finished",
		))

		safe_send(conn, header)

		# 2) Send raw HDF5 bytes as BINARY WebSocket frame
		ok = safe_send(conn, output_hdf5)
		if !ok
			@warn "Client $(conn.id) probably disconnected before receiving HDF5 output"
			return
		end

		@info "Sent HDF5 result to client $(conn.id)"

	catch e
		if isa(e, InterruptException)
			@info "Simulation for client $(conn.id) interrupted/cancelled."
			try
				safe_send(conn, JSON.json(Dict("type"=>"result", "status"=>"cancelled")))
			catch _
			end
		else
			@error "Simulation error for client $(conn.id): $(truncated_error(e))"
			try
				safe_send(conn, JSON.json(Dict("type"=>"result", "status"=>"error", "error"=>string(e))))
			catch _
			end
		end
	finally
		# Clear sim_task if still registered
		lock(clients_lock) do
			if haskey(clients, conn.id)
				c = clients[conn.id]
				clients[conn.id] = ClientConnection(
					c.id, c.ws, c.connected_at, now(),
					c.send_channel, c.send_task, nothing,
				)
			end
		end
	end
end


# ---------------------------------
# Calculate equilibrium KPIs task
# ---------------------------------
#
function calculate_equilibrium_kpis_task(input::Dict, conn::ClientConnection)
	try
		@info "Starting simulation for client $(conn.id) with input $(sim_input)"

		# calculate equilibrium kpis
		kpis = get_equilibrium_kpis(CellParameters(input));

		# Update activity
		lock(clients_lock) do
			if haskey(clients, conn.id)
				c = clients[conn.id]
				clients[conn.id] = ClientConnection(
					c.id, c.ws, c.connected_at, now(),
					c.send_channel, c.send_task, c.sim_task, c.kpi_task,
				)
			end
		end

		# 1) Send JSON data
		header = JSON.json(Dict(
			"type" => "kpis",
			"data" => kpis,
		))

		safe_send(conn, header)

		@info "Sent KPIs result to client $(conn.id)"

	catch e
		if isa(e, InterruptException)
			@info "KPI calculation for client $(conn.id) interrupted/cancelled."
			try
				safe_send(conn, JSON.json(Dict("type"=>"result", "status"=>"cancelled")))
			catch _
			end
		else
			@error "KPI calculation error for client $(conn.id): $(truncated_error(e))"
			try
				safe_send(conn, JSON.json(Dict("type"=>"result", "status"=>"error", "error"=>string(e))))
			catch _
			end
		end
	finally
		# Clear kpi_task if still registered
		lock(clients_lock) do
			if haskey(clients, conn.id)
				c = clients[conn.id]
				clients[conn.id] = ClientConnection(
					c.id, c.ws, c.connected_at, now(),
					c.send_channel, c.send_task, c.sim_task, nothing,
				)
			end
		end
	end
end
