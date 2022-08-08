using NetCDF3
using Test
using NCDatasets

@testset "NetCDF3" begin
    include("test_errors.jl")
    include("test_read.jl")
    include("test_unlimdim.jl")
    include("test_write.jl")
    include("test_dimensions.jl")
    include("test_variables.jl")
end
