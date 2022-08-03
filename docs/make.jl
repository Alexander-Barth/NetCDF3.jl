using Documenter, NetCDF3

makedocs(modules = [NetCDF3], sitename = "NetCDF3.jl")

deploydocs(
    repo = "github.com/Alexander-Barth/NetCDF3.jl.git",
)
