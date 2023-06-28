using HTTP
using Test

import Base: parse

#=
url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.das"
r = HTTP.get(url); body = copy(r.body)
print(String(body))
=#

function parsetype(type)
    if type == "Float32"
        Float32
    elseif type == "Float64"
        Float64
    elseif type == "Int16"
        Int16
    elseif type == "Int32"
        Int32
    elseif type == "Int64"
        Int64
    elseif type == "String"
        String
    else
        error("unknown type $type")
    end
end

struct Dimension
    name::String
    len::Int64
end

struct Variable{T,N,TP}
    name::String
    dims::NTuple{N,Dimension}
    parent::TP
end

struct Grid
    name::String
    arrays
    maps
end

struct Dataset
    name::String
    variables
end


function token_paren(str,bp,ep,i0=1)
    level = 0
    i = i0

    while i <= ncodeunits(str)
        c = str[i]
        if c == bp # (
            level += 1
        elseif c == ep # )
            level -= 1
        end

        if level == 0
            return i
        end
        i = nextind(str,i)
    end
    return nothing # unmatched parentesis
end

str = "{ foo { barα∀ } baz } lala"
i0 = 1
i = token_paren(str,'{','}',i0)

function token_string(str,i0=1,strquote='"')
    i = i0

    @assert str[i] == strquote

    i = nextind(str,i)

    while i <= ncodeunits(str)
        c = str[i]
        if c == strquote
            return (:string,i0:i)
        elseif (c == '\\') && (i < ncodeunits(str))
            i = nextind(str,i)
        end

        i = nextind(str,i)
    end
    return nothing # unmatched parentesis
end

str = "\"foo\" BAR"
type,irange = token_string(str)
@test str[irange] == "\"foo\""

str = """"fo\\\"o" BAR"""
print(str)
type,irange = token_string(str)
@test str[irange] == "\"fo\\\"o\""

function nexttoken(str,i0=1)
    i = i0
    while i <= ncodeunits(str)
        if !(str[i] in (' ','\n'))
            break
        end
        i = nextind(str,i)
    end

    #@show str,i,str[i]
    if i > ncodeunits(str)
        return (:nothing,i0:(i0-1))
    end

    if str[i] == '{'
        j = token_paren(str,'{','}',i)
        return (:curly_braces,i:j)
    elseif str[i] == '['
        j = token_paren(str,'[',']',i)
        return (:square_braces,i:j)
    elseif str[i] == '"'
        return token_string(str,i)
    elseif str[i] in ('=',':',';',',')
        return (Symbol(str[i]),i:i)
    end

    j = i
    while j <= ncodeunits(str)
        #@show j,str[j],str[j] == ' '
        if str[j] in (' ','=','[',']','{','}',':',';','"',',')
            #@show i,j,str[j],prevind(str,j)
            return (:token,i:prevind(str,j))
        end
        j = nextind(str,j)
    end
    println("close")
    return (:token,i:ncodeunits(str))
end


str = "  lala   "
t,irange = nexttoken(str)
@test str[irange] == "lala"


str = "  lala∀   "
t,irange = nexttoken(str)
@test str[irange] == "lala∀"

str = "  { lala {} ∀}   "
t,irange = nexttoken(str)
@test str[irange] == "{ lala {} ∀}"

str = "  { lala {} ∀}   "
t,irange = nexttoken(str)
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
function parse2(str,i=1)
    irange=i:(i-1)

    t,irange = nexttoken(str,last(irange)+1)

    if (t == :nothing) || (str[irange] == "")
        return (:nothing,last(irange)+1)
    end

    if str[irange] == "Dataset"
        #@show str,last(irange)+1
        return parseds(str,last(irange)+1)
    elseif str[irange] == "Grid"
        return parsegrid(str,last(irange)+1)
    elseif str[irange] in ("Float32","Float64","Int16")
        return parsett(str,str[irange],last(irange)+1)
    end

    error("unknown $(str[irange])")
#    @show "this is the end",t,str[irange],i
end


function parsedim(str,i=1)
    irange=i:(i-1)

    t,irange = nexttoken(str,last(irange)+1)
    name = str[irange]

    t,irange = nexttoken(str,last(irange)+1)
    @assert t == Symbol('=')

    t,irange = nexttoken(str,last(irange)+1)
    len = parse(Int64,str[irange])

    return Dimension(name,len)
end


function parsett(str,type,i=1)
    irange=i:(i-1)
#    @show "tt",str[i:end]

    t,irange = nexttoken(str,last(irange)+1)
    name = str[irange]

    dims = []
    t,irange = nexttoken(str,last(irange)+1)

    while t == :square_braces
        d = parsedim(str,first(irange)+1)
        push!(dims,d)
        t,irange = nexttoken(str,last(irange)+1)
    end

    @assert t == Symbol(';')
    T = parsetype(type)
    N = length(dims)
    ds = nothing
    return (Variable{T,N,typeof(ds)}(name,(dims...,),ds),last(irange)+1)
end

function parseds(str,i=1)
    irange=i:(i-1)

    t,irange = nexttoken(str,last(irange)+1)
    @assert t == :curly_braces

    variables = []
    v,iend = parse2(str,first(irange)+1)

    while v !== :nothing
        push!(variables,v)
        v,iend = parse2(str,iend)
    end


    #@show iend
    #@show iend,str[iend]
    t,irange = nexttoken(str,last(irange)+1)
    #@show str[irange]
    name = str[irange]

    t,irange = nexttoken(str,last(irange)+1)
    @assert t == Symbol(';')

    return (Dataset(name,variables),last(irange)+1)
end

function parsegrid(str,i=1)
    #@show "grid",i
    irange=i:(i-1)

    t,irange = nexttoken(str,last(irange)+1)
    @assert t == :curly_braces


    t,irange = nexttoken(str,first(irange)+1)
    @assert str[irange] == "Array"

    t,irange = nexttoken(str,last(irange)+1)
    #@show str[irange]
    @assert str[irange] == ":"

    array,iend = parse2(str,last(irange)+1)
    #@show array

    t,irange = nexttoken(str,iend)
    #@show str[irange]
    @assert str[irange] == "Maps"

    t,irange = nexttoken(str,last(irange)+1)
    #@show str[irange]
    @assert str[irange] == ":"

    maps = []
    v,iend = parse2(str,last(irange)+1)
    while v !== :nothing
        push!(maps,v)
        v,iend = parse2(str,iend)
    end
    #@show v,iend,str[iend]
    t,irange = nexttoken(str,iend+1)
    #@show str[irange]
    name = str[irange]

    t,irange = nexttoken(str,last(irange)+1)
    @assert t == Symbol(';')

    type = "Grid";
    #return ((;type,array,maps,name),last(irange)+1)
    return (Grid(name,array,maps),last(irange)+1)

end


str = dds

data,iend = parse2(str)
@show data

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


function parseatt(str,i=1)
    irange=i:(i-1)
    t,irange = nexttoken(str,last(irange)+1)

    if (t == :nothing) || (str[irange] == "")
        return (nothing,nothing,0)
    end
    T = parsetype(str[irange])

    t,irange = nexttoken(str,last(irange)+1)
    name = str[irange]

    v = T[]

    while true
        t,irange = nexttoken(str,last(irange)+1)

        if t == Symbol(";")
            break
        elseif t == Symbol(",")
        else
            if T == String
                push!(v,str[irange])
            else
                push!(v,parse(T,str[irange]))
            end
        end
    end
    return (name,(v...,),last(irange)+1)
end

function parsedas(str,i=1)
    irange = i:(i-1)

    att = OrderedDict();

    t,irange = nexttoken(str,last(irange)+1)
    @assert str[irange] == "Attributes"

    t,irange0 = nexttoken(str,last(irange)+1)
    @assert t == :curly_braces

    II = first(irange0)+1

    while true
        t,irange = nexttoken(str,II)

        @show t,str[irange]
        if (t == :nothing) || (str[irange] == "")
            break
        end

        varname = str[irange]

        t,irange = nexttoken(str,last(irange)+1)
        @assert t == :curly_braces

        al2 = OrderedDict();

        i = first(irange)+1
        while true
            name,values,i = parseatt(str,i)
            if name == nothing
                break
            end
            al2[name] = values
        end

        att[varname] = al2

        II = last(irange)+1
    end

    return att
end

@show parseatt("Float32 actual_range 88.0000000, -88.0000000;")

@show parseatt("")

str = das

using DataStructures


att = parsedas(str)

@show att

using CommonDataModel: AbstractDataset, variable
import Base: keys


#module OPeNDAP

struct Dataset3 <: AbstractDataset
    url::String
    dds
    das
end


function Dataset3(url::AbstractString)
    dds = String(HTTP.get(string(url,".dds")).body)
    das = String(HTTP.get(string(url,".das")).body)
    Dataset3(url,parse2(dds)[1],parsedas(das))
end

_list_var(d::Dataset) = _list_var.(d.variables)
_list_var(v::Variable) = v.name
_list_var(v::Grid) = _list_var(v.arrays)
_list_var(v) = nothing

Base.keys(ds::Dataset3) = _list_var(ds.dds)

url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz"

ds = Dataset3(url);

keys(ds)
ds



# https://datatracker.ietf.org/doc/html/rfc1832

#=

#url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.dods?lon"
#url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.dods?time"
url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.dods?sst[0:0][0:0][0:0]"
#url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.dods?sst[0:0][0:0][0:3]"

r = HTTP.get(url); body = copy(r.body)

io = IOBuffer(copy(body))


line = readline(io)
@assert line == "Dataset {"
line = readline(io)

@show line
type,var = split(line,limit=2)

T =
    if type == "Float32"
        Float32
    elseif type == "Float64"
        Float64
    elseif type == "Int16"
        Int16
    else
        error("unknown type $type in $url")
    end

for line in eachline(io)

    @show line
    if strip(line) == "Data:"
        break
    end
end

count = hton(read(io,UInt32))
@show Int(count)

a = hton(read(io,Int16))
b = hton(read(io,Int16))
#c = hton(read(io,Int16))

@show a,b,c
data = Vector{T}(undef,count)

for i = 1:count
    if T == Int16
        skip = hton(read(io,Int16))
        @show skip
    end

    data[i] = hton(read(io,T))
end

@show data

#=
readline(io)
s = read(io,10)
@show String(s)

hton(read(io,UInt32))

hton(read(io,Float32))
=#
=#
