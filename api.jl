using HTTP
using HTTP.WebSockets
using UUIDs
using JSON
using Tables
using Base.Threads: ReentrantLock, lock, unlock, @async, wait, Condition
using BattMo
using Logging
using Jutul
using HDF5
using Dates

include("scripts/format_output.jl")
include("scripts/web_socket.jl")
include("scripts/tasks.jl")
include("scripts/documentation.jl")



ws_port = 8080
start_websocket_server(ws_port)

doc_port = 8081
start_documentation_server(doc_port)




