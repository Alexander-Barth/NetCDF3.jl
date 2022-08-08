using NetCDF3
using Test
using NCDatasets
using BenchmarkTools
using Random

sz = (1000,1000,100)
T = Float64
fname = "/tmp/data.nc"
ds = NCDataset(fname,"c",format = :netcdf3_64bit_offset);
data_ref = randn(T,sz)
defVar(ds,"data",data_ref,("lon","lat","time"));
close(ds)

@info "pure julia NetCDF"

nc = NetCDF3.File(fname);
NetCDF3_varid = NetCDF3.nc_inq_varid(nc,:data);
data = zeros(T,sz)
@btime NetCDF3.nc_get_var!(nc,NetCDF3_varid,data);
#close(nc)
@test data == data_ref;

@info "libnetcdf"

ds = NCDataset(fname);
ncvar = ds["data"].var;
ncid = ds.ncid
varid = ncvar.varid

#using Preferences, NetCDF_jll
#set_preferences!(NetCDF_jll, "libnetcdf_path" => "/usr/lib/x86_64-linux-gnu/libnetcdf.so.13")

@btime ccall((:nc_get_var,lib),Cint,(Cint,Cint,Ptr{Nothing}),$ncid,$varid,$data)

close(ds)
@test data == data_ref;

# random access

nobs = 100_000

indices = [ntuple(i -> rand(1:sz[i]),length(sz)) for n = 1:nobs]
data_obs = zeros(nobs)

function test_read!(nc,varid,indices,data_obs)
    for (i,ind) in enumerate(indices)
        @inbounds data_obs[i] = NetCDF3.nc_get_var1(nc,varid,ind)
    end
end

@btime test_read!(nc,NetCDF3_varid,indices,data_obs);

data_obs_ref = [data_ref[ind...] for ind in indices]
@test data_obs == data_obs_ref


data = @btime begin

    @btime ccall((:nc_get_var1,libnetcdf),Cint,(Cint,Cint,Ptr{Csize_t},Ptr{Nothing}),
                 $ncid,$varid,ind,tmp))

    @btime ccall((:nc_get_var1,NCDatasets.libnetcdf),Cint,
                 (Cint,Cint,Ptr{Nothing}),$ncid,$varid,$data)

    [NetCDF3.nc_get_var1($nc,$NetCDF3_varid,ind) for ind in $indices]
end;



indicesC = map(ijk -> collect(reverse(ijk)) .- 1,indices)




#rm(fname)

#=
# Reading a 1000x1000x100 array of Float64 with random data
# save as a NetCDF3 file (with 64-bit offset)

[ Info: Precompiling NetCDF3 [c0b278e5-4161-4a30-804d-e28c605fc747]
[ Info: pure julia NetCDF
  346.326 ms (0 allocations: 0 bytes)
[ Info: libnetcdf
  1.564 s (0 allocations: 0 bytes)
=#
