


function try_write_header(io,dims,attrib,vars,::Type{Toffset},offset0) where Toffset
    _dimids = OrderedDict((k-1,v[2]) for (k,v) in collect(enumerate(dims)))

    seekstart(io)
    write(io,UInt8.(collect("CDF")))

    if Toffset == Int32
        version_byte = UInt8(1)
    else
        version_byte = UInt8(2)
    end

    recs = Int32(0)

    unpack_write(io,version_byte)
    unpack_write(io,recs)

    ndims = length(dims)
    nvars = length(vars)

    unpack_write(io,NC_DIMENSION)
    unpack_write(io,Int32(ndims))
    for (k,v) in dims
        unpack_write(io,String(k))
        unpack_write(io,Int32(v))
    end

    write_attrib(io,attrib)

    unpack_write(io,NC_VARIABLE)
    unpack_write(io,Int32(nvars))

    offset = offset0
    start = Vector{Toffset}(undef,length(vars))

    for v in vars
        T = v.T
        i = v.varid+1
        vsize = prod(_dimids[id] for id in v.dimids) * sizeof(v.T)
        vsize += mod(-vsize,4) # padding

        unpack_write(io,String(v.name))
        unpack_write(io,Int32(length(v.dimids)))
        for dimid in reverse(v.dimids)
            unpack_write(io,Int32(dimid))
        end
        write_attrib(io,v.attrib)
        unpack_write(io,NCTYPE[v.T])
        unpack_write(io,Int32(vsize))
        unpack_write(io,offset)

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
        vars)
end


function nc_def_dim(nc,dimname,dimlength)
    dimid = length(nc.dim)
    nc.dim[Symbol(dimname)] = dimlength
    nc._dimid[dimid] = dimlength
    return dimid
end

function nc_def_var(nc,name,T,dimids)
    offset = 1024
    for v in nc.vars
        offset += v.vsize
    end

    varid = length(nc.vars)
    attrib = OrderedDict{Symbol,Any}()
    sz = reverse(ntuple(i -> nc._dimid[dimids[i]],length(dimids)))

    vsize = prod(filter(!=(0),sz)) * sizeof(T)
    vsize += mod(-vsize,4) # padding

    push!(nc.vars,(; varid, name, dimids, attrib, T, vsize, sz))
    push!(nc.start,offset)
    return varid
end


function nc_put_var(nc,varid,data)
    i = varid+1
    @assert eltype(data) == nc.vars[i].T
    @show nc.start[i]

    seek(nc.io,nc.start[i])
    unpack_write(nc.io,data)
end

function nc_close(nc)
    memio = IOBuffer()
    offset0 = 1024
    Toffset = Int

    start = try_write_header(memio,nc.dim,nc.attrib,nc.vars,Toffset,offset0)
    @show offset0, start[1]
    @assert offset0 >= start[1]

    # otherwise need to shift data in file to make room for larger header
    seekstart(nc.io)
    write(nc.io,take!(memio))
    close(nc.io)
end
