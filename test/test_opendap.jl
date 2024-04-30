using Test
using BenchmarkTools
using CommonDataModel

#=
url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.das"
r = HTTP.get(url); body = copy(r.body)
print(String(body))
=#
include("opendap.jl")

using .OPENDAP: token_paren, next_token, parse_dds, parse_das, token_string,
    _list_var, dods_index, variable, dimnames

str = "{ foo { barα∀ } baz } lala"
i0 = 1
i = token_paren(str,'{','}',i0)

str = "\"foo\" BAR"
type,irange = token_string(str)
@test str[irange] == "\"foo\""

str = """"fo\\\"o" BAR"""
print(str)
type,irange = token_string(str)
@test str[irange] == "\"fo\\\"o\""



str = "  lala   "
t,irange = next_token(str)
@test str[irange] == "lala"


str = "  lala∀   "
t,irange = next_token(str)
@test str[irange] == "lala∀"

str = "  { lala {} ∀}   "
t,irange = next_token(str)
@test str[irange] == "{ lala {} ∀}"

str = "  { lala {} ∀}   "
t,irange = next_token(str)
@test str[irange] == "{ lala {} ∀}"



dds = """Dataset {
    Float32 lat[lat = 89];
    Float32 lon[lon = 180];
    Float64 time[time = 1857];
    Float64 time_bnds[time = 1857][nbnds = 2];
    Grid {
      Array:
        Int16 sst[time = 1857][lat = 89][lon = 180];
      Maps:
        Float64 time[time = 1857];
        Float32 lat[lat = 89];
        Float32 lon[lon = 180];
    } sst;
} sst.mnmean.nc;"""

#=
dds = """Dataset {
    Float32 lat[lat = 89];
    Float32 lon[lon = 180];
} sst.mnmean.nc;"""
=#


str = dds

data,iend = parse_dds(str)

das = """Attributes {
    lat {
        String units "degrees_north";
        String long_name "Latitude";
        Float32 actual_range 88.0000000, -88.0000000;
        String standard_name "latitude_north";
        String axis "y";
        String coordinate_defines "center";
    }
    lon {
        String units "degrees_east";
        String long_name "Longitude";
        Float32 actual_range 0.00000000, 358.000000;
        String standard_name "longitude_east";
        String axis "x";
        String coordinate_defines "center";
    }
    time {
        String units "days since 1800-1-1 00:00:00";
        String long_name "Time";
        Float64 actual_range 19723.00000000000, 76214.00000000000;
        String delta_t "0000-01-00 00:00:00";
        String avg_period "0000-01-00 00:00:00";
        String prev_avg_period "0000-00-07 00:00:00";
        String standard_name "time";
        String axis "t";
    }
    time_bnds {
        String long_name "Time Boundaries";
    }
    sst {
        String long_name "Monthly Means of Sea Surface Temperature";
        Float32 valid_range -5.00000000, 40.0000000;
        Float32 actual_range -1.79999995, 34.2399979;
        String units "degC";
        Float32 add_offset 0.00000000;
        Float32 scale_factor 0.00999999978;
        Int16 missing_value 32767;
        Int16 precision 2;
        Int16 least_significant_digit 1;
        String var_desc "Sea Surface Temperature";
        String dataset "NOAA Extended Reconstructed SST V3";
        String level_desc "Surface";
        String statistic "Mean";
        String parent_stat "Mean";
    }
    NC_GLOBAL {
        String title "NOAA Extended Reconstructed SST V3";
        String conventions "CF-1.0";
        String history "created 09/2007 by CAS";
        String comments "The extended reconstructed sea surface temperature (ERSST)
was constructed using the most recently available
Comprehensive Ocean-Atmosphere Data Set (COADS) SST data
and improved statistical methods that allow stable
reconstruction using sparse data.
Currently, ERSST version 2 (ERSST.v2) and version 3 (ERSST.v3) are available from NCDC.
 ERSST.v3 is an improved extended reconstruction over version 2.
 Most of the improvements are justified by testing with simulated data.
 The major differences are caused by the improved low-frequency (LF) tuning of ERSST.v3
which reduces the SST anomaly damping before 1930 using the optimized parameters.
 Beginning in 1985, ERSST.v3 is also improved by explicitly including
 bias-adjusted satellite infrared data from AVHRR.";
        String platform "Model";
        String source "NOAA/NESDIS/National Climatic Data Center";
        String institution "NOAA/NESDIS/National Climatic Data Center";
        String references "http://www.ncdc.noaa.gov/oa/climate/research/sst/ersstv3.php
http://www.cdc.noaa.gov/cdc/data.noaa.ersst.html";
        String citation "Smith, T.M., R.W. Reynolds, Thomas C. Peterson, and Jay Lawrimore 2007: Improvements to NOAA's Historical Merged Land-Ocean Surface Temperature Analysis (1880-2006). In press. Journal of Climate (ERSSTV3).
Smith, T.M., and R.W. Reynolds, 2003: Extended Reconstruction of Global Sea Surface Temperatures Based on COADS Data (1854-1997). Journal of Climate, 16, 1495-1510. ERSSTV1
 Smith, T.M., and R.W. Reynolds, 2004: Improved Extended Reconstruction of SST (1854-1997). Journal of Climate, 17, 2466-2477.";
    }
    DODS_EXTRA {
        String Unlimited_Dimension "time";
    }
}"""


#@show parseatt("Float32 actual_range 88.0000000, -88.0000000;")

#@show parseatt("")

str = das



att = parse_das(str)




#module OPeNDAP

url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz"

ds = OPENDAP.Dataset(url);
ds
keys(ds)
_list_var(ds,ds.dds)

ds
v = variable(ds,"lat");
size(v)
dimnames(v)

CommonDataModel.attribs(v)
ENV["JULIA_DEBUG"] = "CommonDataModel"

ds


#keys(ds)
#ds



v = variable(ds,"time");
data = v[:]

@show data[1:5]


index = (1:10,1:3)


dods_index(index)
t = ds["time"][:]

sst = ds["sst"][1:3,1:3,1:2]

lon = ds["lon"][:]
lat = ds["lat"][:]

sst = @time ds["sst"][:,:,1];

import NCDatasets
dsnc = NCDatasets.Dataset(url);
sst = @time dsnc["sst"][:,:,1];

a = replace(sst,missing => NaN)

#using PyPlot
#pcolormesh(lon,lat,a')
url = "https://n5eil02u.ecs.nsidc.org/opendap/SMAP/SPL4SMAU.006/2015.03.31/SMAP_L4_SM_aup_20150331T030000_Vv6032_001.h5"

using URIs


username_escaped = URIs.escapeuri(ENV["CMEMS_USERNAME"])
password_escaped = URIs.escapeuri(ENV["CMEMS_PASSWORD"])

url = "https://my.cmems-du.eu/thredds/dodsC/bs-ulg-car-rean-m"
url2 = string(URI(URI(url),userinfo = string(username_escaped,":",password_escaped)))

#ds = OPENDAP.Dataset(url2);
a = ds["talk"][:,:,1,1]
a = replace(a,missing => NaN)
pcolormesh(a')
