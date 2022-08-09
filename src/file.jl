
# reading

@inline function unpack_read(io,T)
    return hton(read(io,T))
end

function unpack_read!(io,data::AbstractArray)
    read!(io,data)
    @inbounds @simd for i in eachindex(data)
        data[i] = hton(data[i])
    end
    return data
end

function unpack_read(io,T::Type{String},Tsize)
    count = unpack_read(io,Tsize)
    s = String(read(io,count))
    read(io,mod(-count,4)) # read padding
    return s
end

# writing

@inline function pack_write(io,data)
    return write(io,ntoh(data))
end

function pack_write(io,data::AbstractArray)
    for d in data
        write(io,ntoh(d))
    end
end

function pack_write(io,data::String,Tsize)
    count = Tsize(sizeof(data))
    pack_write(io,count)
    pack_write(io,Vector{UInt8}(data))
    for p in 1:mod(-count,4)
        pack_write(io,0x00)
    end
end

function nc_open(io,write)
    magic = read(io,3)
    if String(magic) != "CDF"
        error(
            "This is not a NetCDF 3 file. You can check the kind of NetCDF " *
            "file by running `ncdump -k filename.nc`. For NetCDF 3 file you " *
            "should see `classic` or `64-bit offset`. NetCDF3.jl cannot read " *
            "NetCDF 4 (based on HDF5) files."
        )
    end

    version = unpack_read(io,UInt8)

    Toffset = (version == 1 ? Int32 : Int64)
    Tsize = (version < 5 ? Int32 : Int64)

    recs = Int64(unpack_read(io,Tsize))

    # dimension
    header = unpack_read(io,UInt32)
    @assert header in [NC_DIMENSION, ZERO]

    count = unpack_read(io,Tsize)

    dim = OrderedDict{Symbol,Int}()
    _dimid = OrderedDict{Int,Int}()
    for i = 0:count-1
        s = unpack_read(io,String,Tsize)
        len = unpack_read(io,Tsize)
        dim[Symbol(s)] = len
        _dimid[i] = len
    end

    # global attributes
    attrib = read_attributes(io,Tsize)

    # variables
    header = unpack_read(io,UInt32)
    @debug "header var: $header, $NC_VARIABLE"
    @assert header in [NC_VARIABLE, ZERO]

    count = unpack_read(io,Tsize)
    start = Vector{Int64}(undef,count)
    @debug "number of variables: $count"

    vars = [
        begin
            name = Symbol(unpack_read(io,String,Tsize))
            @debug "variable $name"
            ndims = unpack_read(io,Tsize)
            dimids = reverse(((unpack_read(io,Tsize) for i in 1:ndims)...,))
            attrib = read_attributes(io,Tsize)
            nc_type = unpack_read(io,UInt32)
            T = TYPEMAP[nc_type]
            vsize = unpack_read(io,Tsize)
            start[varid+1] = unpack_read(io,Toffset)
            sz = ntuple(i -> _dimid[dimids[i]],ndims)

            (; varid, name, dimids, attrib, T, vsize, sz)
        end
        for varid = 0:count-1
            ]

    File(
        io,
        write,
        version,
        recs,
        dim,
        _dimid,
        attrib,
        start,
        vars,
        ReentrantLock(),
    )
end

File(fname::AbstractString,args...) = File(open(fname),args...)

File(io::IO) = nc_open(io,false)

"""

# Supported `format` values:

* `:netcdf3_classic`: classic netCDF format supporting only files smaller than 2GB.
* `:netcdf3_64bit_offset`: improved netCDF format supporting files larger than 2GB.
* `:netcdf5_64bit_data`: improved netCDF format supporting 64-bit integer data types.

netCDF4 is not supported and not within scope.
"""
function File(fname::AbstractString,mode="r"; lock = true, format = :netcdf3_classic)
    if mode == "r"
        io = open(fname,write=false,lock=lock)
        nc_open(io,false)
    elseif mode == "c"
        io = open(fname,"w+",lock=lock)
        nc_create(io, format = format)
    end
end


function close(nc::File)
    close(nc.io)
end


function _vsize(_dimid,dimids,T)
    sz = ntuple(i -> _dimid[dimids[i]],length(dimids))
    vsize = prod(filter(!=(0),sz)) * sizeof(T)
    vsize += mod(-vsize,4) # padding
    return sz,vsize
end

function try_write_header(io,recs,dims,attrib,vars,
                          ::Type{Toffset},::Type{Tsize},offset0) where {Toffset,Tsize}
    _dimids = OrderedDict((k-1,v[2]) for (k,v) in collect(enumerate(dims)))

    seekstart(io)
    write(io,UInt8.(collect("CDF")))


    if Tsize == Int32
        if Toffset == Int32
            version = UInt8(1)
        else
            version = UInt8(2)
        end
    else
        version = UInt8(5)
    end

    pack_write(io,version)
    pack_write(io,Tsize(recs))

    ndims = length(dims)
    nvars = length(vars)

    pack_write(io,NC_DIMENSION)
    pack_write(io,Tsize(ndims))
    for (k,v) in dims
        pack_write(io,String(k),Tsize)
        pack_write(io,Tsize(v))
    end

    write_attributes(io,attrib,Tsize)

    pack_write(io,NC_VARIABLE)
    pack_write(io,Tsize(nvars))

    offset = offset0
    start = Vector{Toffset}(undef,length(vars))

    for v in vars
        T = v.T
        i = v.varid+1

        sz,vsize = _vsize(_dimids,v.dimids,T)

        pack_write(io,String(v.name),Tsize)
        pack_write(io,Tsize(length(v.dimids)))
        for dimid in reverse(v.dimids)
            pack_write(io,Tsize(dimid))
        end
        write_attributes(io,v.attrib,Tsize)
        pack_write(io,NCTYPE[v.T])
        pack_write(io,Tsize(vsize))
        pack_write(io,Toffset(offset))

        start[i] = offset
        offset += Toffset(vsize)
    end

    return start
end

function nc_create(io; format=:netcdf3_64bit_offset)
    version =
        if format == :netcdf3_classic
            UInt8(1)
        elseif format == :netcdf3_64bit_offset
            UInt8(2)
        elseif format == :netcdf5_64bit_data
            UInt8(5)
        else
            error("unsupported format $format")
        end

    recs = Int64(0)
    dim=OrderedDict{Symbol,Int}()
    _dimid=OrderedDict{Int,Int}()
    attrib=OrderedDict{Symbol,Any}()
    start=Vector{Int64}()
    vars=[]
    write = true

    File(
        io,
        write,
        version,
        recs,
        dim,
        _dimid,
        attrib,
        start,
        vars,
        ReentrantLock(),
    )
end


function nc_close(nc)
    memio = IOBuffer()
    offset0 = 1024
    Toffset = Int

    Toffset = (nc.version == 1 ? Int32 : Int64)
    Tsize = (nc.version < 5 ? Int32 : Int64)

    start = try_write_header(memio,nc.recs,nc.dim,nc.attrib,nc.vars,Toffset,Tsize,offset0)
    @debug offset0, start[1]
    @assert offset0 >= start[1]

    # otherwise need to shift data in file to make room for larger header
    seekstart(nc.io)
    write(nc.io,take!(memio))
    close(nc.io)
end


function _recsize(nc)
    recsize = 0
    for v in nc.vars
        if any(dimid -> nc._dimid[dimid] == 0, v.dimids)
            recsize += v.vsize
        end
    end

    return recsize
end
