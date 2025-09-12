using Pkg
Pkg.update()
Pkg.add("HTTP")
# Pkg.add("BattMo")
Pkg.add(url = "https://github.com/BattMoTeam/BattMo.jl",
	rev = "wglmakie")
Pkg.add("WGLMakie")
Pkg.add("Jutul")
Pkg.add("JSON")
Pkg.add("HDF5")
Pkg.add("PackageCompiler")
Pkg.add("UUIDs")
Pkg.add("Bonito")


using HTTP, BattMo, JSON, Jutul, UUIDs, HDF5, PackageCompiler
Pkg.precompile()
