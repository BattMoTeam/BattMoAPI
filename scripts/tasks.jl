
# -------------------------
# Get default sets
# -------------------------

function get_default_sets_for_client()
	dest = generate_default_parameter_files(tempname(); print = false, force = true)
	files = filter(f -> endswith(f, ".json"), readdir(dest, join = true))
	result = Dict()
	for f in files
		json_data = JSON.parse(read(f, String))
		result[basename(f)] = json_data
	end
	return result
end


# -------------------------
# Calculate KPIs
# -------------------------

function get_equilibrium_kpis(parameters)
	cell_parameters = CellParameters(parameters)
	cell_kpis_from_set = get_equilibrium_kpis(cell_parameters)
	return cell_kpis_from_set

end

# -------------------------
# Run simulation
# -------------------------

function run_simulation_task(params, ws::HTTP.WebSockets.WebSocket)
	id = string(UUIDs.uuid4())
	cond = Condition()

	t = @async begin
		lock(simulation_lock) do
			progress = 0.0
			result = nothing
			try
				# Example: simulate progress
				for step in 1:10
					sleep(0.5)  # simulate computation
					progress = step / 10
					HTTP.WebSockets.send(ws, JSON.json(Dict(
						"type" => "simulation_progress",
						"task_id" => id,
						"progress" => progress,
					)))
				end
				# Run actual simulation
				output = run_simulation(FullSimulationInput(params))

				result = format_output_arrow(ouput)
			catch e
				@error "Simulation failed: $e"
				result = Dict("error" => string(e))
			end

			simulations[id] = (Task(() -> result), cond, 1.0, result)
			notify(cond)
			# Send completion message
			HTTP.WebSockets.send(ws, result; isbinary = true)
		end # lock
	end # @async

	simulations[id] = (t, cond, 0.0, nothing)
	return Dict("task_id" => id)
end
