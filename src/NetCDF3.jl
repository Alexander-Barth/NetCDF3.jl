module NetCDF3

using DataStructures
import Base: close


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

function unpack_read(io,T)
    return hton(read(io,T))
end

function unpack_read!(io,data::AbstractArray)
    read!(io,data)
    @inbounds @simd for i in eachindex(data)
        data[i] = hton(data[i])
    end
    return data
end

function unpack_read(io,T::Type{String})
    count = unpack_read(io,Int32)
    s = String(read(io,count))
    read(io,mod(-count,4)) # read padding
    return s
end

function read_attribute_values(io)
    nc_type = unpack_read(io,UInt32)
    n = unpack_read(io,Int32)
    T = TYPEMAP[nc_type]
    values = [unpack_read(io,T) for i = 1:n]
    read(io, mod(-(n*sizeof(T)), 4))  # read padding
    return values
end

function read_attributes(io)
    attrib = OrderedDict{Symbol,Any}()
    header = unpack_read(io,UInt32)

    @assert header in [NC_ATTRIBUTE, ZERO]

    count = unpack_read(io,Int32)
    for i = 1:count
        name = unpack_read(io,String)
        values = read_attribute_values(io)
        attrib[Symbol(name)] = values
    end

    return attrib
end


struct NetCDFFile0{TIO <: IO, TV}
    io::TIO
    version_byte::UInt8
    recs::Int32
    dim::OrderedDict{Symbol,Int}
    _dimid::OrderedDict{Int,Int}
    attrib::OrderedDict{Symbol,Any}
    start::Vector{Int64}
    vars::Vector{TV}
end

NetCDFFile0(fname::AbstractString) = NetCDFFile0(open(fname))

function NetCDFFile0(io::IO)
    magic = read(io,3)
    @assert String(magic) == "CDF"

    version_byte = unpack_read(io,UInt8)
    recs = unpack_read(io,Int32)

    # dimension
    header = unpack_read(io,UInt32)
    @assert header in [NC_DIMENSION, ZERO]
    count = unpack_read(io,Int32)

    dim = OrderedDict{Symbol,Int}()
    _dimid = OrderedDict{Int,Int}()
    for i = 0:count-1
        s = unpack_read(io,String)
        len = unpack_read(io,Int32)
        dim[Symbol(s)] = len
        _dimid[i] = len
    end

    # global attributes
    attrib = read_attributes(io)

    # variables
    header = unpack_read(io,UInt32)
    @assert header in [NC_VARIABLE, ZERO]

    Toffset = (version_byte == 1 ? Int32 : Int64)
    count = unpack_read(io,Int32)
    start = Vector{Int64}(undef,count)

    vars = [
        begin
            name = unpack_read(io,String)
            ndims = unpack_read(io,Int32)
            dimids = [unpack_read(io,Int32) for i in 1:ndims]
            vattrib = read_attributes(io)
            nc_type = unpack_read(io,UInt32)
            T = TYPEMAP[nc_type]
            vsize = unpack_read(io,Int32)
            start[i+1] = unpack_read(io,Toffset)
            sz = reverse(ntuple(i -> _dimid[dimids[i]],ndims))

            (; name, dimids, vattrib, T, vsize, sz)
        end
        for i = 0:count-1
            ]

    NetCDFFile0(
        io,
        version_byte,
        recs,
        dim,
        _dimid,
        attrib,
        start,
        vars)
end


function nc_get_var!(nc::NetCDFFile0,varid,data)
    index = varid+1

    if size(data) != nc.vars[index].sz
        error("wrong size of data (got $(size(data)), expected $(nc.vars[index].sz))")
    end

    pos = position(nc.io)
    seek(nc.io,nc.start[index])
    unpack_read!(nc.io,data)
    seek(nc.io,pos)
    return data
end

function nc_get_var(nc::NetCDFFile0,varid)
    v = nc.vars[varid+1]
    data = Array{v.T,length(v.sz)}(undef,v.sz...)
    return nc_get_var!(nc,varid,data)
end


function close(nc::NetCDFFile0)
    close(nc.io)
end


end # module
