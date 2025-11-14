using Pkg
Pkg.update()
Pkg.add("HTTP")
Pkg.add("BattMo")
Pkg.add("Jutul")
Pkg.add("JSON")
Pkg.add("HDF5")
Pkg.add("Tables")
Pkg.add("PackageCompiler")
Pkg.add("UUIDs")
Pkg.add("Dates")
Pkg.add("Logging")


using HTTP, BattMo, JSON, Jutul, UUIDs, HDF5, PackageCompiler, Tables, Dates, Logging
Pkg.precompile()
