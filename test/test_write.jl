using NetCDF3
using Test
using NetCDF3: unpack_write, NC_DIMENSION, NC_VARIABLE, NC_ATTRIBUTE, NCTYPE, write_attrib
using NCDatasets
using DataStructures

fname = tempname()

dims = OrderedDict(
    :lon => 2,
    :lat => 3,
)

attrib = OrderedDict(
    :foo =>  [Int32(1)],
    :bar =>  [Int8(1)],
)

data_ref = rand(Int32.(1:10),2,3);

var_metadata = OrderedDict(
    :lon =>  (
        type = Float64,
        dimids = (0,),
        attrib = OrderedDict(
            :units => Vector{UInt8}("degree east"),
        )
    ),
    :data =>  (
        type = eltype(data_ref),
        dimids = (0,1),
        attrib = OrderedDict(
            :add_offset => 1.)
    ),
)


var = OrderedDict(
    :lon =>  Float64[1,2],
    :data => data_ref,
)


#---

function write_header(io,dims,attrib,var_metadata,::Type{Toffset},offset0) where Toffset
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
    nvars = length(var_metadata)

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
    start = Vector{Toffset}(undef,length(var_metadata))

    for (i,(k,v)) in enumerate(var_metadata)
        T = v.type
        vsize = prod(_dimids[id] for id in v.dimids) * sizeof(T)
        #vsize = length(v.data)*sizeof(T)
        vsize += mod(-vsize,4) # padding

        unpack_write(io,String(k))
        unpack_write(io,Int32(length(v.dimids)))
        for dimid in reverse(v.dimids)
            unpack_write(io,Int32(dimid))
        end
        write_attrib(io,v.attrib)
        unpack_write(io,NCTYPE[T])
        unpack_write(io,Int32(vsize))
        unpack_write(io,offset)

        start[i] = offset
        offset += Toffset(vsize)
    end

    return start
end

version_byte = 2
Toffset = (version_byte == 1 ? Int32 : Int64)

io = open(fname,"w")
seekstart(io)
offset0 = Toffset(1024)
min_padding = 256

start = write_header(io,dims,attrib,var_metadata,Toffset,offset0)
if position(io)+min_padding > start[1]
    # need larger header section
    offset0 = position(io)+min_padding
    start = write_header(io,dims,attrib,var_metadata,Toffset,offset0)
end

padding = start[1] - position(io)

@assert padding >= 0
# todo need to increase header section

for i = 1:padding
    unpack_write(io,0x00)
end

@show padding

for (i,(k,data)) in enumerate(var)
    T = eltype(data)
    vsize = length(data)*sizeof(T)
    vsize += mod(-vsize,4) # padding

    seek(io,start[i])
    unpack_write(io,data)

    v_padding = vsize - length(data)*sizeof(T)
    for i = 1:v_padding
        unpack_write(io,0x00)
    end

end

close(io)


#run(`ncdump $fname`)
#NCDataset(fname)

#nc = NetCDF3.File(fname)

ds = NCDataset(fname)
@show ds
@test ds["data"].var[:,:] == data_ref
@test ds["lon"].var[:] == var[:lon]
close(ds)
