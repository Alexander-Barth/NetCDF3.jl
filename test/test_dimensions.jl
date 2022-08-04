using NetCDF3
using Test
using NCDatasets

fname = tempname()

nc = NetCDF3.File(fname,"c");

dimid1 = NetCDF3.nc_def_dim(nc,:lon,2)
dimid2 = NetCDF3.nc_def_dim(nc,:lat,3)
dimid3 = NetCDF3.nc_def_dim(nc,:time,0)

@test NetCDF3.nc_inq_ndims(nc) == 3
@test NetCDF3.nc_inq_unlimdims(nc) == (NetCDF3.nc_inq_dimid(nc,:time),)

NetCDF3.nc_rename_dim(nc,dimid1,:longitude)
@test NetCDF3.nc_inq_dimid(nc,:longitude) == dimid1

NetCDF3.nc_rename_dim(nc,dimid1,:lon)
@test NetCDF3.nc_inq_dimid(nc,:lon) == dimid1


@test_throws Exception NetCDF3.nc_inq_dimid(nc,:longitude)
@test_throws Exception NetCDF3.nc_inq_dimname(nc,999)
