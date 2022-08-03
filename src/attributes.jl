

function nc_put_att(nc,varid,name,data)
    nc.vars[varid+1].attrib[Symbol(name)] = data
end

function nc_get_att(nc,varid,name)
    return nc.vars[varid+1].attrib[Symbol(name)]
end
