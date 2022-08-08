
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

function unpack_read(io,T::Type{String})
    count = unpack_read(io,Int32)
    #@show count
    s = String(read(io,count))
    #@show "read p ",mod(-count,4)
    read(io,mod(-count,4)) # read padding
    #@show s
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

function pack_write(io,data::String)
    count = Int32(sizeof(data))
    #@show count
    pack_write(io,count)
    #@show data,Vector{UInt8}(data)
    #pack_write(io,unsafe_wrap(Vector{UInt8}, pointer(data), count))
    pack_write(io,Vector{UInt8}(data))
    for p in 1:mod(-count,4)
        #@show "p"
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
            dimids = reverse(((unpack_read(io,Int32) for i in 1:ndims)...,))
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
        vars,
        ReentrantLock(),
    )
end

File(fname::AbstractString,args...) = File(open(fname),args...)

File(io::IO) = nc_open(io,false)

function File(fname::AbstractString,mode="r"; lock = true)
    if mode == "r"
        io = open(fname,write=false,lock=lock)
        nc_open(io,false)
    elseif mode == "c"
        io = open(fname,"w+",lock=lock)
        nc_create(io)
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

function try_write_header(io,recs,dims,attrib,vars,::Type{Toffset},offset0) where Toffset
    _dimids = OrderedDict((k-1,v[2]) for (k,v) in collect(enumerate(dims)))

    seekstart(io)
    write(io,UInt8.(collect("CDF")))

    if Toffset == Int32
        version_byte = UInt8(1)
    else
        version_byte = UInt8(2)
    end

    pack_write(io,version_byte)
    pack_write(io,Int32(recs))

    ndims = length(dims)
    nvars = length(vars)

    pack_write(io,NC_DIMENSION)
    pack_write(io,Int32(ndims))
    for (k,v) in dims
        pack_write(io,String(k))
        pack_write(io,Int32(v))
    end

    write_attributes(io,attrib)

    pack_write(io,NC_VARIABLE)
    pack_write(io,Int32(nvars))

    offset = offset0
    start = Vector{Toffset}(undef,length(vars))

    for v in vars
        T = v.T
        i = v.varid+1

        sz,vsize = _vsize(_dimids,v.dimids,T)

        pack_write(io,String(v.name))
        pack_write(io,Int32(length(v.dimids)))
        for dimid in reverse(v.dimids)
            pack_write(io,Int32(dimid))
        end
        write_attributes(io,v.attrib)
        pack_write(io,NCTYPE[v.T])
        pack_write(io,Int32(vsize))
        pack_write(io,offset)

        start[i] = offset
        offset += Toffset(vsize)
    end

    return start
end

function write_header(io,dims,attrib,vars,Toffset)
    version_byte = 2
    Toffset = (version_byte == 1 ? Int32 : Int64)

    seekstart(io)
    offset0 = Toffset(1024)
    min_padding = 256

    start = try_write_header(io,dims,attrib,vars,Toffset,offset0)
    if position(io)+min_padding > start[1]
        # need larger header section
        offset0 = position(io)+min_padding
        start = write_header(io,dims,attrib,vars,Toffset,offset0)
    end

    return start
end



function nc_create(io,format=:netcdf3_64bit_offset)
    version_byte =
        if format == :netcdf3_64bit_offset
            UInt8(2)
        else
            UInt8(1)
        end

    recs = Int32(0)
    dim=OrderedDict{Symbol,Int}()
    _dimid=OrderedDict{Int,Int}()
    attrib=OrderedDict{Symbol,Any}()
    start=Vector{Int64}()
    vars=[]
    write = true

    File(
        io,
        write,
        version_byte,
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

    start = try_write_header(memio,nc.recs,nc.dim,nc.attrib,nc.vars,Toffset,offset0)
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
