

Experimental package of a pure julia NetCDF 3 file format reader and writer.


The NetCDF API follows generally the C API with the following Julia-specific changes (mostly for performance reason)

* names should be `Symbol`s instead of `String`s
* Ordering of the dimensions of lists like `dimid`, `stride`, `count`,... should be reverded relative the the C API (as Julia uses column-major ordering)
*


# Credits

[Pupynere](https://pypi.org/project/pupynere/) from Roberto De Almeida (licenced MIT) was extremely helpful to understand the NetCDF Classic Format Specification.
