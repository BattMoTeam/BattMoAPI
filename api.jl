using HTTP
using HTTP.WebSockets
using UUIDs
using JSON
using HDF5
using Base.Threads: ReentrantLock, lock, unlock, @async, wait, Condition
using BattMo
using Logging
using Jutul
using Arrow
using Tables

include("scripts/web_socket.jl")
include("scripts/tasks.jl")
include("scripts/format_output.jl")
include("scripts/api_documentation.jl")

# -------------------------
# Global state
# -------------------------

const simulation_lock = ReentrantLock()
const simulations = Dict{String, Tuple{Task, Condition}}()
const clients = Dict{UUID, HTTP.WebSockets.WebSocket}()

# -------------------------
# Run servers
# -------------------------

ws_port = 8080
@async start_websocket_server(ws_port)


# Prevent exit
wait(Condition())


doc_port = 8081
# start_documentation_server(doc_port)
