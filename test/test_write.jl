using NetCDF3
using Test
using NCDatasets


data_ref = rand(Int32.(1:10),2,3);
lon_ref = Float64[1,2]

fname = tempname()

for format = [
    :netcdf3_classic,
    :netcdf3_64bit_offset,
    :netcdf5_64bit_data,
]

    #fname = "/tmp/tmp.nc"
    nc = NetCDF3.File(fname,"c"; format = format)
    dimid1 = NetCDF3.nc_def_dim(nc,:lon,2)
    dimid2 = NetCDF3.nc_def_dim(nc,:lat,3)
    varid = NetCDF3.nc_def_var(nc,:lon,Float64,(dimid1,))

    NetCDF3.nc_put_var(nc,varid,lon_ref)
    NetCDF3.nc_put_att(nc,varid,:units,Vector{UInt8}("degree east"))

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
    @test ds["lon"].var[:] == lon_ref
    close(ds)
    rm(fname)
end
