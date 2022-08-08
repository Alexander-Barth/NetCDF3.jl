

function Var(nc,varid::Integer)
    v = nc.vars[varid+1]

    _isrec = any(dimid -> nc._dimid[dimid] == 0, v.dimids)
    return Var{v.T,length(v.dimids),typeof(nc),_isrec}(
                nc,
                v.name,
                v.sz,
                v.varid,
                v.dimids,
                v.vsize)
end


function Var(nc,varid,T,name,dimids)
    sz,vsize = _vsize(nc._dimids,dimids,T)

    _isrec = any(dimid -> nc._dimid[dimid] == 0, dimids)

    return Var{T,length(dimids),typeof(nc),_isrec}(
                nc,
                name,
                sz,
                varid,
                dimids,
                vsize)
end

#Base.eltype(v::Var{T}) where T = T

function Base.size(var::Var)
    ntuple(length(var.dimids)) do i
        dimlen = var.nc._dimid[var.dimids[i]]
        if dimlen == 0
            return var.nc.recs
        else
            dimlen
        end
    end
end

function Base.show(io::IO,mime::MIME"text/plain",var::Var)
    print(io,"Variable ",var.name," of size ", size(var))
end


function Base.getindex(var::Var,indices...)
    nc_get_var(var.nc,var)[indices...]
end

#Base.show(io::IO, m::MIME"text/plain", v::Var) = show(io, m, v)

isrec(v::Var{T,N,TFile,Tisrec}) where {T,N,TFile,Tisrec} = Tisrec


function nc_inq_varid(nc::File,varname)
    vn = Symbol(varname)

    for v in nc.vars
        if v.name == vn
            return Var(nc,v.varid)
        end
    end

    error("variable $varname not found in $(nc.io)")
end


function nc_inq_var(nc::File,var)
    for v in nc.vars
        if v.varid == var.varid
            return (v.name,v.T,v.dimids,length(v.attrib))
        end
    end

    error("variable with id $varid not found in $(nc.io)")
end

nc_inq_varname(nc::File,var) = var.name
nc_inq_vartype(nc::File,var) = eltype(var)
nc_inq_varndims(nc::File,var) = ndims(var)
nc_inq_vardimid(nc::File,var) = var.dimids
nc_inq_varnatts(nc::File,varid) = nc_inq_var(nc,varid)[4]

nc_inq_varids(nc::File) = ((Var(nc,v.varid) for v in nc.vars)...,)

function nc_def_var(nc,name,T,dimids)
    offset = 1024
    for v in nc.vars
        offset += v.vsize
    end

    varid = length(nc.vars)
    attrib = OrderedDict{Symbol,Any}()

    sz,vsize = _vsize(nc._dimid,dimids,T)

    push!(nc.vars,(; varid, name, dimids, attrib, T, vsize, sz))
    push!(nc.start,offset)

    v = Var(nc,varid)
    if isrec(v) && nc.recs > 0
        error("All record variables need to be defined before any data is written.")
    end

    return v
end

function nc_put_var(nc,var,data)
    i = var.varid+1
    v = nc.vars[i]
    @assert eltype(data) == nc.vars[i].T

    if !isrec(var)
        seek(nc.io,nc.start[i])
        pack_write(nc.io,data)
    else
        recsize = _recsize(nc)

        lock(nc.lock) do
            nc.recs = max(nc.recs,size(data)[end])
        end

        for irec = 1:size(data)[end]
            seek(nc.io,nc.start[i] + (irec-1) * recsize)
            indices = ntuple(i -> (v.sz[i] == 0 ? (irec:irec) : Colon()),length(v.sz))
            pack_write(nc.io,view(data,indices...))
        end
    end
end


function nc_get_var!(nc::File,var,data)
    index = var.varid+1

    if size(data) != size(var)
        error("wrong size of data (got $(size(data)), expected $(size(var)))")
    end

    pos = position(nc.io)

    if isrec(var)
        recsize = _recsize(nc)

        for irec = 1:nc.recs
            seek(nc.io,nc.start[index] + (irec-1) * recsize)
            indices = ntuple(i -> (var.size[i] == 0 ? (irec:irec) : Colon()),ndims(var))
            unpack_read!(nc.io,view(data,indices...))
        end
    else
        seek(nc.io,nc.start[index])
        unpack_read!(nc.io,data)
    end

    seek(nc.io,pos)
    return data
end

function nc_get_var(nc::File,var)
    varid = var.varid
    sz = size(var)
    data = Array{eltype(var),length(sz)}(undef,sz...)
    return nc_get_var!(nc,var,data)
end

function nc_get_var1(nc::File,var,index)
    index = var.varid+1

    if isrec(var)
    else
        seek(nc.io,nc.start[index] + )
        unpack_read!(nc.io,data)
    end
end
