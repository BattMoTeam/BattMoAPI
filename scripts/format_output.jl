
function format_output_arrow(output)

	time_series = get_output_time_series(output)
	states = get_output_states(output)
	metrics = get_output_metrics(output)
	quantities = [time_series, states, metrics]

	# Prepare dictionary for columnar table
	columns = Dict{String, Any}()

	# Helper to extract quantity name and vector
	for quantity in quantities
		for (name, data) in quantity
			columns[name] = data
		end
	end

	# Convert to Tables.jl compatible columnar table
	table = Tables.columntable(columns)

	# Serialize to Arrow
	io = IOBuffer()
	Arrow.write(io, table)
	arrow_bytes = take!(io)

	return arrow_bytes

end
