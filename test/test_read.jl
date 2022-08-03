using NetCDF3
using Test
using NCDatasets

sz = (2,3,4)
T = Float64
fname = tempname()
ds = NCDataset(fname,"c",format = :netcdf3_64bit_offset);
data_ref = randn(T,sz)
defVar(ds,"foo",data_ref,("lon","lat","time"));
close(ds)

nc = NetCDF3.File(fname);

varid = NetCDF3.nc_inq_varid(nc,:foo)
data = zeros(T,sz)
NetCDF3.nc_get_var!(nc,varid,data);
close(nc)

@test data == data_ref;

rm(fname)
