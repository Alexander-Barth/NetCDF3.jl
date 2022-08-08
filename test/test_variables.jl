using NetCDF3
using Test
using NCDatasets


data_ref = rand(Int32.(1:10),2,3);
lon_ref = Float64[1,2]

fname = tempname()

nc = NetCDF3.File(fname,"c")
dimid1 = NetCDF3.nc_def_dim(nc,:lon,2)
dimid2 = NetCDF3.nc_def_dim(nc,:lat,3)
varid = NetCDF3.nc_def_var(nc,:lon,Float64,(dimid1,))
NetCDF3.nc_put_var(nc,varid,lon_ref)
NetCDF3.nc_put_att(nc,varid,:units,Vector{UInt8}("degree east"))

varid = NetCDF3.nc_def_var(nc,:data,Int32,(dimid1,dimid2))
NetCDF3.nc_put_var(nc,varid,data_ref)
NetCDF3.nc_put_att(nc,varid,:add_offset,[Int32(0)])


NetCDF3.nc_close(nc)



nc = NetCDF3.File(fname,"r")


@test NetCDF3.nc_inq_varids(nc) === (
    NetCDF3.nc_inq_varid(nc,:lon),
    NetCDF3.nc_inq_varid(nc,:data));

varid = NetCDF3.nc_inq_varid(nc,:data)

@test NetCDF3.nc_inq_var(nc,varid) == (:data, Int32, (0,1), 1)
@test NetCDF3.nc_inq_varname(nc,varid) == :data
@test NetCDF3.nc_inq_vartype(nc,varid) == Int32
@test NetCDF3.nc_inq_varndims(nc,varid) == 2
@test NetCDF3.nc_inq_vardimid(nc,varid) == (0,1)
@test NetCDF3.nc_inq_varnatts(nc,varid) == 1


var = varid


for j = 1:size(data_ref,2)
    for i = 1:size(data_ref,1)
        @test NetCDF3.nc_get_var1(nc,varid,(i,j)) == data_ref[i,j]
    end
end


@btime NetCDF3.nc_get_var1(nc,varid,(1,1))



#close(nc)
