using NetCDF3
using Test

fname = tempname()
write(fname,"not a NetCDF3 file")

@test_throws Exception NetCDF3.File(fname)
