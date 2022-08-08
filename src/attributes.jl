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

function write_attributes(io,attrib)
    pack_write(io,NC_ATTRIBUTE)
    pack_write(io,Int32(length(attrib)))

    for (k,v) in attrib
        n = length(v)
        T = eltype(v)

        pack_write(io,String(k))
        pack_write(io,NCTYPE[T])
        pack_write(io,Int32(n))
        pack_write(io,v)
        for p in 1:mod(-(n*sizeof(T)), 4)
            pack_write(io,0x00)
        end
    end
end


function nc_put_att(nc,var,name,data)
    nc.vars[var.varid+1].attrib[Symbol(name)] = data
end

function nc_get_att(nc,var,name)
    return nc.vars[var.varid+1].attrib[Symbol(name)]
end
