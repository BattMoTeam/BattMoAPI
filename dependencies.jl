using Pkg
Pkg.update()

Pkg.add(PackageSpec(name="HTTP", version="1.10.19"))
Pkg.add(PackageSpec(name="BattMo", version="0.1.9"))
Pkg.add(PackageSpec(name="Jutul"))
Pkg.add(PackageSpec(name="JSON", version="1.2.0"))
Pkg.add(PackageSpec(name="HDF5", version="0.17.2"))
Pkg.add(PackageSpec(name="PackageCompiler"))
Pkg.add(PackageSpec(name="UUIDs", version = "1.11.0"))



using HTTP, BattMo, JSON, Jutul, UUIDs, HDF5, PackageCompiler
Pkg.precompile()