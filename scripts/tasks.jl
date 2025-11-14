function run_simulation_task(input, ws::Union{WebSocket, Nothing} = nothing)

	try

		output = run_simulation(FullSimulationInput(input));

		# if output_path !== nothing
		# lock(simulation_lock) do
		output_arrow = format_output_arrow(output)
		return output_arrow
		# end

		# end

	catch e
		WebSockets.send(ws, "Simulation error: $e")
		@error "Simulation error: $e"

	finally
		if stop_condition !== nothing
			lock(simulation_lock) do
				notify(stop_condition)
			end
		end

	end


end
