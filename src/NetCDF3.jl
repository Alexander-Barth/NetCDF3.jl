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

const NCTYPE = Dict((v,k) for (k,v) in TYPEMAP)

# reading

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
    #@show count
    s = String(read(io,count))
    #@show "read p ",mod(-count,4)
    read(io,mod(-count,4)) # read padding
    #@show s
    return s
end

function read_attribute_values(io)
    nc_type = unpack_read(io,UInt32)
    n = unpack_read(io,Int32)
    @show n,nc_type
    T = TYPEMAP[nc_type]
    @show T
    values = [unpack_read(io,T) for i = 1:n]
    read(io, mod(-(n*sizeof(T)), 4))  # read padding
    return values
end

function read_attributes(io)
    attrib = OrderedDict{Symbol,Any}()
    header = unpack_read(io,UInt32)
    @assert header in [NC_ATTRIBUTE, ZERO]

    count = unpack_read(io,Int32)
    @show count,header == NC_ATTRIBUTE
    for i = 1:count
        name = unpack_read(io,String)
        values = read_attribute_values(io)
        attrib[Symbol(name)] = values
    end

    return attrib
end

# writing

function unpack_write(io,data)
    #@show "write ",data
    return write(io,ntoh(data))
end

function unpack_write(io,data::AbstractArray)
    #@show data,"jjjj",typeof(data)
    for d in data
        #@show d
        write(io,ntoh(d))
        #@show "end",d
    end
end

function unpack_write(io,data::String)
    count = Int32(sizeof(data))
    #@show count
    unpack_write(io,count)
    #@show data,Vector{UInt8}(data)
    #unpack_write(io,unsafe_wrap(Vector{UInt8}, pointer(data), count))
    unpack_write(io,Vector{UInt8}(data))
    for p in 1:mod(-count,4)
        #@show "p"
        unpack_write(io,0x00)
    end
end

function write_attrib(io,attrib)
    unpack_write(io,NC_ATTRIBUTE)
    unpack_write(io,Int32(length(attrib)))

    for (k,v) in attrib
        n = length(v)
        T = eltype(v)

        unpack_write(io,String(k))
        unpack_write(io,NCTYPE[T])
        unpack_write(io,Int32(n))
        unpack_write(io,v)
        for p in 1:mod(-(n*sizeof(T)), 4)
            unpack_write(io,0x00)
        end
    end
end


function nc_open(io,write)
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
        #@show s
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
            name = Symbol(unpack_read(io,String))
            ndims = unpack_read(io,Int32)
            dimids = reverse([unpack_read(io,Int32) for i in 1:ndims])
            attrib = read_attributes(io)
            nc_type = unpack_read(io,UInt32)
            T = TYPEMAP[nc_type]
            vsize = unpack_read(io,Int32)
            start[varid+1] = unpack_read(io,Toffset)
            sz = ntuple(i -> _dimid[dimids[i]],ndims)

            (; varid, name, dimids, attrib, T, vsize, sz)
        end
        for varid = 0:count-1
            ]

    File(
        io,
        write,
        version_byte,
        recs,
        dim,
        _dimid,
        attrib,
        start,
        vars)
end

struct File{TIO <: IO, TV}
    io::TIO
    write::Bool
    version_byte::UInt8
    recs::Int32
    dim::OrderedDict{Symbol,Int}
    _dimid::OrderedDict{Int,Int}
    attrib::OrderedDict{Symbol,Any}
    start::Vector{Int64}
    vars::Vector{TV}
end

File(fname::AbstractString,args...) = File(open(fname),args...)
File(io::IO) = nc_open(io,false)
function File(fname::AbstractString,mode="r")
    if mode == "r"
        io = open(fname,write=false)
        nc_open(io,false)
    elseif mode == "c"
        io = open(fname,"w+")
        nc_create(io)
    end
end

function isrec(nc::File,varid)
    v = nc.vars[varid+1]
    return any(dimid -> nc._dimid[dimid] == 0, v.dimids)
end

function inq_size(nc::File,varid)
    v = nc.vars[varid+1]

    sz = ntuple(length(v.dimids)) do i
        dimlen = nc._dimid[v.dimids[i]]
        if dimlen == 0
            return nc.recs
        else
            dimlen
        end
    end

    return sz
#=    if isrec(nc,varid)
        return ntuple(i -> (v.sz[i] == 0 ? nc.recs : v.sz[i]),length(v.sz))
    else
        return v.sz
    end=#
end


function nc_get_var!(nc::File,varid,data)
    index = varid+1
    v = nc.vars[index]
    sz = inq_size(nc,varid)
    if size(data) != sz
        error("wrong size of data (got $(size(data)), expected $(sz))")
    end

    pos = position(nc.io)

    if isrec(nc,varid)
        recsize = 0
        for v in nc.vars
            if any(dimid -> nc._dimid[dimid] == 0, v.dimids)
                recsize += v.vsize
            end
        end

        for irec = 1:nc.recs
            seek(nc.io,nc.start[varid+1] + (irec-1) * recsize)
            indices = ntuple(i -> (v.sz[i] == 0 ? (irec:irec) : Colon()),length(v.sz))
            unpack_read!(nc.io,view(data,indices...))
        end
    else
        @show nc.start[index]
        seek(nc.io,nc.start[index])
        unpack_read!(nc.io,data)
    end

    seek(nc.io,pos)
    return data
end

function nc_get_var(nc::File,varid)
    v = nc.vars[varid+1]
    sz = inq_size(nc,varid)
    data = Array{v.T,length(sz)}(undef,sz...)
    return nc_get_var!(nc,varid,data)
end


function close(nc::File)
    close(nc.io)
end



function nc_inq_varid(nc::File,varname)
    vn = Symbol(varname)

    for v in nc.vars
        if v.name == vn
            return v.varid
        end
    end

    error("variable $varname not found in $(nc.io)")
end

include("write.jl")
include("attributes.jl")

end # module
