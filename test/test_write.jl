using NetCDF3
using Test
using NetCDF3: unpack_write, NC_DIMENSION, NC_VARIABLE, NC_ATTRIBUTE, NCTYPE, write_attrib, write_header
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

vars = [
    (
        varid = 0,
        name = :lon,
        T = Float64,
        dimids = (0,),
        attrib = OrderedDict(
            :units => Vector{UInt8}("degree east"),
        )
    ),
    (
        varid = 1,
        name = :data,
        T = eltype(data_ref),
        dimids = (0,1),
        attrib = OrderedDict(
            :add_offset => 1.)
    ),
]


var = OrderedDict(
    :lon =>  Float64[1,2],
    :data => data_ref,
)


#---

Toffset = Int64
io = open(fname,"w")
start = write_header(io,dims,attrib,vars,Toffset)

for (i,(k,data)) in enumerate(var)
    T = eltype(data)
    vsize = length(data)*sizeof(T)
    vsize += mod(-vsize,4) # padding

    seek(io,start[i])
    unpack_write(io,data)
end

close(io)


#=


=#

#run(`ncdump $fname`)
#NCDataset(fname)

#nc = NetCDF3.File(fname)

ds = NCDataset(fname)
@test ds["data"].var[:,:] == data_ref
@test ds["lon"].var[:] == var[:lon]
close(ds)



fname = tempname()


nc = NetCDF3.File(fname,"c")
dimid1 = NetCDF3.nc_def_dim(nc,:lon,2)
dimid2 = NetCDF3.nc_def_dim(nc,:lat,3)
varid = NetCDF3.nc_def_var(nc,:lon,Float64,(dimid1,))
NetCDF3.nc_put_var(nc,varid,var[:lon])

varid = NetCDF3.nc_def_var(nc,:data,Int32,(dimid1,dimid2))
NetCDF3.nc_put_att(nc,varid,:add_offset,[Int32(0)])

NetCDF3.nc_put_var(nc,varid,data_ref)

data = NetCDF3.nc_get_var(nc,varid)
@test data == data_ref

NetCDF3.nc_close(nc)

nc = NetCDF3.File(fname,"r")
varid = NetCDF3.nc_inq_varid(nc,:data);
data = NetCDF3.nc_get_var(nc,varid)

add_offset = NetCDF3.nc_get_att(nc,varid,:add_offset)

@test add_offset == [0]

ds = NCDataset(fname)
#@show ds

@test ds["data"].attrib["add_offset"] == 0
@test ds["data"].var[:,:] == data_ref
#@test ds["lon"].var[:] == var[:lon]
close(ds)
