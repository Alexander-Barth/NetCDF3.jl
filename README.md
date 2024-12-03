
[![Build Status](https://github.com/Alexander-Barth/NetCDF3.jl/workflows/CI/badge.svg)](https://github.com/Alexander-Barth/NetCDF3.jl/actions)
[![codecov](https://codecov.io/github/Alexander-Barth/NetCDF3.jl/graph/badge.svg?token=3I93JPOLVO)](https://codecov.io/github/Alexander-Barth/NetCDF3.jl)


Experimental package of a pure julia NetCDF 3 file format reader and writer.


The NetCDF API follows generally the C API with the following Julia-specific changes (mostly for performance reason)

* names should be `Symbol`s instead of `String`s
* Ordering of the dimensions of lists like `dimid`, `stride`, `count`,... should be reversed relative the the C API (as Julia uses column-major ordering)



# Supported Formats

* CDF-1: the original and default NetCDF format
* CDF-2: Format introduced in NetCDF 3.6.0 (mode `NC_64BIT_OFFSET`)
* CDF-5: Format introduced in NetCDF 4.4.0 (mode `NC_64BIT_DATA`)

NetCDF4 (based on HDF5) is not supported and not within scope.

# Credits

[Pupynere](https://pypi.org/project/pupynere/) from Roberto De Almeida (licenced MIT) was extremely helpful to understand the NetCDF Classic Format Specification.
