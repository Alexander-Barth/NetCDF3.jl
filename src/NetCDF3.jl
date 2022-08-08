module NetCDF3

using DataStructures
import Base: close, eltype, size, getindex, setindex

# based on https://pypi.org/project/pupynere/
# by Roberto De Almeida (MIT)
# and
# The NetCDF Classic Format Specification
# https://web.archive.org/web/20220731205122/https://docs.unidata.ucar.edu/netcdf-c/current/file_format_specifications.html

# use 32-bit integers (UInt32) instead of a 4 byte array to avoid
# heap allocations

const ZERO = 0x00000000
const NC_BYTE = 0x00000001
const NC_CHAR = 0x00000002
const NC_SHORT = 0x00000003
const NC_INT = 0x00000004
const NC_FLOAT = 0x00000005
const NC_DOUBLE = 0x00000006
const NC_DIMENSION = 0x0000000a
const NC_VARIABLE = 0x0000000b
const NC_ATTRIBUTE = 0x0000000c

const TYPEMAP = Dict(
    NC_BYTE => Int8,
    NC_CHAR => UInt8,
    NC_SHORT => Int16,
    NC_INT => Int32,
    NC_FLOAT => Float32,
    NC_DOUBLE => Float64,
)

const NCTYPE = Dict((v,k) for (k,v) in TYPEMAP)

include("types.jl")
include("file.jl")
include("dimensions.jl")
include("attributes.jl")
include("variables.jl")

end # module
