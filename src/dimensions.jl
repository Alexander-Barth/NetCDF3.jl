function nc_def_dim(nc,dimname,dimlength)
    dimid = length(nc.dim)
    nc.dim[Symbol(dimname)] = dimlength
    nc._dimid[dimid] = dimlength
    return dimid
end
