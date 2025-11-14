function write_nested(f, name, data)
	if isa(data, AbstractDict)
		g = create_group(f, name)
		for (k, v) in data
			write_nested(g, k, v)
		end
	else
		write(f, name, collect(data))  # ensures StepRange → Array
	end
end

function format_output_hdf5(output::SimulationOutput)
	tmpfile = tempname() * ".h5"
	h5open(tmpfile, "w") do f
		# Save time_series
		for (name, data) in output.time_series
			write_nested(f, name, data)
		end
		# Save states
		g_states = create_group(f, "states")
		for (name, data) in output.states
			write_nested(g_states, name, data)
		end
		# Save metrics
		g_metrics = create_group(f, "metrics")
		for (name, data) in output.metrics
			write_nested(g_metrics, name, data)
		end
	end
	bytes = read(tmpfile)
	rm(tmpfile; force = true)  # clean up temp file
	return bytes
end
