using Pkg
Pkg.update()
Pkg.add("HTTP")
Pkg.add("BattMo")
Pkg.add("Jutul")
Pkg.add("JSON")
Pkg.add("HDF5")
Pkg.add("PackageCompiler")
Pkg.add("UUIDs")


using HTTP, BattMo, JSON, Jutul, UUIDs, HDF5, PackageCompiler
Pkg.precompile()