


function nc_def_dim(nc,dimname,dimlength)
    dimid = length(nc.dim)
    nc.dim[Symbol(dimname)] = dimlength
    nc._dimid[dimid] = dimlength
    return dimid
end

function nc_inq_dim(nc,dimid)
    for (_dimid,(dimname,dimlen)) in enumerate(nc.dim)
         if _dimid-1 == dimid
            return dimname,dimlen
        end
    end
    error("dimension with id $dimid not found")
end

function nc_inq_dimid(nc,name)
    for (_dimid,(dimname,dimlen)) in enumerate(nc.dim)
         if dimname == Symbol(name)
            return _dimid-1
        end
    end
    error("dimension with name $name not found")
end

nc_inq_dimname(nc,dimid) = nc_inq_dim(nc,dimid)[1]
nc_inq_ndims(nc) = length(nc.dim)

nc_inq_unlimdims(nc) = ((k for (k,v) in nc._dimid if v == 0)...,)


nc_inq_dimlen(nc,dimid) = nc._dimid[dimid]

function nc_rename_dim(nc,dimid::Integer,name)
    old = copy(nc.dim)
    empty!(nc.dim)
    for (_dimid,(k,v)) in enumerate(old)
        if (_dimid-1) == dimid
            nc.dim[name] = v
        else
            nc.dim[k] = v
        end
    end
end

