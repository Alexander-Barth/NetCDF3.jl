module OPENDAP

using HTTP
using CommonDataModel
import CommonDataModel: AbstractDataset, variable, AbstractVariable,
    attribnames, attrib, dimnames, name
import Base: keys, size, getindex, parse
using DataStructures


function parse_type(type)
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

struct Variable{T,N,TP} <: AbstractVariable{T,N}
    name::String
    dims::NTuple{N,Dimension}
    parent::TP
end

CommonDataModel.name(v::Variable) = v.name

struct Grid
    name::String
    arrays
    maps
end

struct DDSDataset
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


function next_token(str,i0=1)
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
        if str[j] in (' ','=','[',']','{','}',':',';','"',',')
            return (:token,i:prevind(str,j))
        end
        j = nextind(str,j)
    end

    return (:token,i:ncodeunits(str))
end

function parse_dds(str,i=1)
    irange=i:(i-1)

    t,irange = next_token(str,last(irange)+1)

    if (t == :nothing) || (str[irange] == "")
        return (:nothing,last(irange)+1)
    end

    if str[irange] == "Dataset"
        return parse_ds(str,last(irange)+1)
    elseif str[irange] == "Grid"
        return parse_grid(str,last(irange)+1)
    elseif str[irange] in ("Float32","Float64","Int16")
        return parse_variable(str,str[irange],last(irange)+1)
    end

    error("unknown $(str[irange])")
end


function parse_dimension(str,i=1)
    irange=i:(i-1)

    t,irange = next_token(str,last(irange)+1)
    name = str[irange]

    t,irange = next_token(str,last(irange)+1)
    @assert t == Symbol('=')

    t,irange = next_token(str,last(irange)+1)
    len = parse(Int64,str[irange])

    return Dimension(name,len)
end


function parse_variable(str,type,i=1)
    irange=i:(i-1)

    t,irange = next_token(str,last(irange)+1)
    name = str[irange]

    dims = []
    t,irange = next_token(str,last(irange)+1)

    while t == :square_braces
        d = parse_dimension(str,first(irange)+1)
        push!(dims,d)
        t,irange = next_token(str,last(irange)+1)
    end

    @assert t == Symbol(';')
    T = parse_type(type)
    N = length(dims)
    ds = nothing
    return (Variable{T,N,typeof(ds)}(name,(dims...,),ds),last(irange)+1)
end

function parse_ds(str,i=1)
    irange=i:(i-1)

    t,irange = next_token(str,last(irange)+1)
    @assert t == :curly_braces

    variables = []
    v,iend = parse_dds(str,first(irange)+1)

    while v !== :nothing
        push!(variables,v)
        v,iend = parse_dds(str,iend)
    end


    t,irange = next_token(str,last(irange)+1)
    name = str[irange]

    t,irange = next_token(str,last(irange)+1)
    @assert t == Symbol(';')

    return (DDSDataset(name,variables),last(irange)+1)
end

function parse_grid(str,i=1)
    irange=i:(i-1)

    t,irange = next_token(str,last(irange)+1)
    @assert t == :curly_braces


    t,irange = next_token(str,first(irange)+1)
    @assert lowercase(str[irange]) == "array"

    t,irange = next_token(str,last(irange)+1)
    @assert str[irange] == ":"

    array,iend = parse_dds(str,last(irange)+1)

    t,irange = next_token(str,iend)
    @assert lowercase(str[irange]) == "maps"

    t,irange = next_token(str,last(irange)+1)
    @assert str[irange] == ":"

    maps = []
    v,iend = parse_dds(str,last(irange)+1)
    while v !== :nothing
        push!(maps,v)
        v,iend = parse_dds(str,iend)
    end

    t,irange = next_token(str,iend+1)
    name = str[irange]

    t,irange = next_token(str,last(irange)+1)
    @assert t == Symbol(';')

    type = "Grid";
    return (Grid(name,array,maps),last(irange)+1)

end



function parse_attibute(str,i=1)
    irange=i:(i-1)
    t,irange = next_token(str,last(irange)+1)

    if (t == :nothing) || (str[irange] == "")
        return (nothing,nothing,0)
    end
    T = parse_type(str[irange])

    t,irange = next_token(str,last(irange)+1)
    name = str[irange]

    v = T[]

    while true
        t,irange = next_token(str,last(irange)+1)

        if t == Symbol(";")
            break
        elseif t == Symbol(",")
        else
            if T == String
                push!(v,str[irange][2:end-1]) # skip quotes
            else
                push!(v,parse(T,str[irange]))
            end
        end
    end

    va =
        if length(v) == 1
            v[1]
        else
            v
        end
    #@info "attrib" name,va

    return (name,va,last(irange)+1)
end

function parse_das(str,i=1)
    irange = i:(i-1)

    att = OrderedDict();

    t,irange = next_token(str,last(irange)+1)
    @assert str[irange] == "Attributes"

    t,irange0 = next_token(str,last(irange)+1)
    @assert t == :curly_braces

    II = first(irange0)+1

    while true
        t,irange = next_token(str,II)

        #@show t,str[irange]
        if (t == :nothing) || (str[irange] == "")
            break
        end

        varname = str[irange]

        t,irange = next_token(str,last(irange)+1)
        @assert t == :curly_braces

        al2 = OrderedDict();

        i = first(irange)+1
        while true
            name,values,i = parse_attibute(str,i)
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

_list_var(ds,d::DDSDataset) = _list_var.(Ref(ds),d.variables)
_list_var(ds,v::Variable{T,N}) where {T,N} = Variable{T,N,typeof(ds)}(v.name,v.dims,ds)
_list_var(ds,v::Grid) = _list_var(ds,v.arrays)
_list_var(ds,v) = nothing

struct Dataset <: AbstractDataset
    url::String
    dds
    das
end

CommonDataModel.attribnames(ds::Dataset) = keys(ds.das["NC_GLOBAL"])
CommonDataModel.attrib(ds::Dataset,name::Union{AbstractString, Symbol}) = ds.das["NC_GLOBAL"][name]
CommonDataModel.attribnames(v::Variable) = keys(v.parent.das[name(v)])
function CommonDataModel.attrib(v::Variable,attname::Union{AbstractString, Symbol})
    v.parent.das[name(v)][attname]
end

Base.size(v::Variable) = reverse(ntuple(i -> v.dims[i].len,ndims(v)))
CommonDataModel.dimnames(v::Variable) = reverse(ntuple(i -> v.dims[i].name,ndims(v)))


function Dataset(url::AbstractString)
    dds = String(HTTP.get(string(url,".dds")).body)
    das = String(HTTP.get(string(url,".das")).body)
    Dataset(url,parse_dds(dds)[1],parse_das(das))
end


Base.keys(ds::Dataset) = name.(_list_var(ds,ds.dds))
function CommonDataModel.variable(ds::Dataset,n::Union{AbstractString, Symbol})
    for v in _list_var(ds,ds.dds)
        if name(v) == n
            return v
        end
    end
    error("no variable $n in dataset $(ds.url)")
end


dods_index(index::NTuple{N,<:AbstractRange}) where N = join(ntuple(i -> string('[',index[i] .- 1,']'),length(index)))
dods_index(index::NTuple{N,Colon}) where N = ""



# From NCDatasets
# the difficulty here is to make the size inferrable by the compiler
@inline _shape_after_slice(sz,indexes...) = __sh(sz,(),1,indexes...)
@inline __sh(sz,sh,n,i::Integer,indexes...) = __sh(sz,sh,               n+1,indexes...)
@inline __sh(sz,sh,n,i::Colon,  indexes...) = __sh(sz,(sh...,sz[n]),    n+1,indexes...)
@inline __sh(sz,sh,n,i,         indexes...) = __sh(sz,(sh...,length(i)),n+1,indexes...)
@inline __sh(sz,sh,n) = sh


_normalizeindex(n,ind::Base.OneTo) = 1:1:ind.stop
_normalizeindex(n,ind::Colon) = 1:1:n
_normalizeindex(n,ind::Int) = ind:1:ind
_normalizeindex(n,ind::UnitRange) = StepRange(ind)
_normalizeindex(n,ind::StepRange) = ind
_normalizeindex(n,ind) = error("unsupported index")

# indexes can be longer than sz
function normalizeindexes(sz,indexes)
    return ntuple(i -> _normalizeindex(sz[i],indexes[i]), length(sz))
end

#=
function Base.getindex(v::Variable{T,N},index...) where {T,N}
    ind = ntuple(N) do i
        if index[i] isa Number
            index:index
        elseif index[i] isa Colon
            1:size(v,i)
        elseif index[i] isa AbstractRange
            index[i]
        else
            error("index $index")
        end
    end
    #@show ind
    return v[ind...]
end
=#


function Base.getindex(v::Variable{T,N},indexes...) where {T,N}
    sz = size(v)
    nind = normalizeindexes(sz,indexes)

    url = string(v.parent.url,".dods?",name(v),dods_index(reverse(nind)))

    sz2 = _shape_after_slice(sz,indexes...)

    @debug "URL" url sz sz2 nind
    # https://datatracker.ietf.org/doc/html/rfc1832


    #url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.dods?lon"
    #url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.dods?time"
    #url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.dods?sst[0:0][0:0][0:0]"
    #url = "http://test.opendap.org/dap/data/nc/sst.mnmean.nc.gz.dods?sst[0:0][0:0][0:3]"

    r = HTTP.get(url)
    io = IOBuffer(r.body)

    line = readline(io)
    @assert line == "Dataset {"

    for line in eachline(io)
        @debug "data header" line
        if strip(line) == "Data:"
            break
        end
    end

    count = hton(read(io,UInt32))

    a = hton(read(io,Int16))
    b = hton(read(io,Int16))

    @debug "count " a,b,count
    data = Array{T,length(sz2)}(undef,sz2)

    @assert length(data) == count
    @inbounds for i = 1:length(data)
        if T == Int16
            skip = hton(read(io,Int16))
        end

        data[i] = hton(read(io,T))
    end

    return data
end

end
