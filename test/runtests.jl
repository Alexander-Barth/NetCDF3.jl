using NetCDF3
using Test
using NCDatasets
using BenchmarkTools

#=
sz = (1000,1000,100)
T = Float64
fname = tempname()
ds = NCDataset(fname,"c",format = :netcdf3_64bit_offset);
data_ref = randn(T,sz)
defVar(ds,"foo",data_ref,("lon","lat","time"));
close(ds)

@info "pure julia NetCDF"

nc = NetCDF3.File(fname);
varid = NetCDF3.nc_inq_varid(nc,:foo);
data = zeros(T,sz)
@time NetCDF3.nc_get_var!(nc,varid,data);
close(nc)
@test data == data_ref;

@info "libnetcdf"

ds = NCDataset(fname);
ncvar = ds["foo"].var;
ncid = ds.ncid
varid = ncvar.varid

@btime ccall((:nc_get_var,NCDatasets.libnetcdf),Cint,(Cint,Cint,Ptr{Nothing}),$ncid,$varid,$data)

close(ds)
@test data == data_ref;

rm(fname)
=#

#=
# Reading a 1000x1000x100 array of Float64 with random data
# save as a NetCDF3 file (with 64-bit offset)

[ Info: Precompiling NetCDF3 [c0b278e5-4161-4a30-804d-e28c605fc747]
[ Info: pure julia NetCDF
  346.326 ms (0 allocations: 0 bytes)
[ Info: libnetcdf
  1.564 s (0 allocations: 0 bytes)

=#


include("test_read.jl")
include("test_unlimdim.jl")
include("test_write.jl")
