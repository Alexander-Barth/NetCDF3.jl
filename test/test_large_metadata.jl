using NetCDF3
using Test
using NCDatasets
using NetCDF3: NC_GLOBAL, nc_put_att, nc_get_att, nc_def_dim,
    nc_def_var, nc_close, nc_put_var
using Random


orig = Vector{UInt8}("0123456789A")
io = IOBuffer()
write(io,orig)
pos = 2
gap_size = 4
buffer = Vector{UInt8}(undef,2)
NetCDF3.file_shift!(io,pos,gap_size,buffer)
seek(io,pos); write(io,"?"^gap_size)

new = take!(io)

@test orig[1:pos] == new[1:pos]
@test orig[pos+1:end] == new[pos+gap_size+1:end]


#---

Random.seed!(123)
data_ref = rand(Int32.(1:10),2,3);
lon_ref = Float64[1,2]

fname = tempname()

format = :netcdf3_classic

fname = "/tmp/tmp.nc"
nc = NetCDF3.File(
    fname,"c"; format = format,
    header_size_hint = 1024,
)

dimid1 = nc_def_dim(nc,:lon,2)
dimid2 = nc_def_dim(nc,:lat,3)

varid = nc_def_var(nc,:data,Int32,(dimid1,dimid2))
nc_put_var(nc,varid,data_ref)


for i = 1:30
    nc_put_att(nc,NC_GLOBAL,"attribute-$i",Vector{UInt8}("attribute-$i"))
end

nc_close(nc)


nc = NetCDF3.File(fname,"r")
varid = NetCDF3.nc_inq_varid(nc,:data);
data = NetCDF3.nc_get_var(nc,varid)
@test data == data_ref


ds = NCDataset(fname)
#@show ds

@test ds["data"].var[:,:] == data_ref
close(ds)

