

function nc_inq_varid(nc::File,varname)
    vn = Symbol(varname)

    for v in nc.vars
        if v.name == vn
            return v.varid
        end
    end

    error("variable $varname not found in $(nc.io)")
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

    seek(nc.io,nc.start[i])
    pack_write(nc.io,data)
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
