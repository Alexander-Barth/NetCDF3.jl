using NetCDF3
using Test
using NCDatasets

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

nc = NetCDF3.NetCDFFile0(fname);

varid = NetCDF3.nc_inq_varid(nc,:foo)
data = NetCDF3.nc_get_var(nc,varid)
@test data == data_ref

varid = NetCDF3.nc_inq_varid(nc,:time)
time = NetCDF3.nc_get_var(nc,varid)
@test time == time_ref
