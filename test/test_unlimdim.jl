using NetCDF3
using Test
using NCDatasets

# read
sz = (2,3,4)
T = Float64
fname = tempname()
data_ref = T.(rand(1:10,sz))
time_ref = T.(1:sz[3])

ds = NCDataset(fname,"c",format = :netcdf3_64bit_offset);
defDim(ds,"lon",sz[1])
defDim(ds,"lat",sz[2])
defDim(ds,"time",Inf)

nclon = defVar(ds,"lon",T,("lon",))
nclat = defVar(ds,"lat",T,("lat",))
nctime = defVar(ds,"time",T,("time",))
ncvar = defVar(ds,"foo",T,("lon","lat","time"));
nclon[:] = 1:sz[1]
nclat[:] = 1:sz[2]
nctime[:] = time_ref
ncvar[:,:,:] = data_ref
close(ds)

nc = NetCDF3.File(fname);

@test NetCDF3.nc_inq_ndims(nc) == 3
@test NetCDF3.nc_inq_unlimdims(nc) == (NetCDF3.nc_inq_dimid(nc,:time),)



varid = NetCDF3.nc_inq_varid(nc,:foo)
data = NetCDF3.nc_get_var(nc,varid)
@test data == data_ref

varid = NetCDF3.nc_inq_varid(nc,:time)
time = NetCDF3.nc_get_var(nc,varid)
@test time == time_ref



# write

data_ref = rand(Int32.(1:10),2,3);
lon_ref = Float64[1,2]

fname = tempname()

nc = NetCDF3.File(fname,"c")
dimid1 = NetCDF3.nc_def_dim(nc,:lon,2)
dimid2 = NetCDF3.nc_def_dim(nc,:lat,0) # unlimited
#varid = NetCDF3.nc_def_var(nc,:lon,Float64,(dimid1,))
#NetCDF3.nc_put_var(nc,varid,lon_ref)
#NetCDF3.nc_put_att(nc,varid,:units,Vector{UInt8}("degree east"))

varid = NetCDF3.nc_def_var(nc,:data,Int32,(dimid1,dimid2))
NetCDF3.nc_put_var(nc,varid,data_ref)

data = NetCDF3.nc_get_var(nc,varid)
@test data == data_ref

NetCDF3.nc_close(nc)

nc = NetCDF3.File(fname,"r")
varid = NetCDF3.nc_inq_varid(nc,:data);
data = NetCDF3.nc_get_var(nc,varid)
@test data == data_ref


ds = NCDataset(fname)
#@show ds
@test ds["data"].var[:,:] == data_ref
#@test ds["lon"].var[:] == lon_ref
close(ds)
