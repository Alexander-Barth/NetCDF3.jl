mutable struct File{TIO <: IO, TV}
    io::TIO
    write::Bool
    version::UInt8
    recs::Int64
    dim::OrderedDict{Symbol,Int}
    _dimid::OrderedDict{Int,Int}
    attrib::OrderedDict{Symbol,Any}
    start::Vector{Int64}
    vars::Vector{TV}
    header_size_hint::Int64
    lock::ReentrantLock
end


# note: mutable information (like attributes, start offset)
# should go in File
struct Var{T,N,TFile,isrec} <: AbstractArray{T,N}
    nc::TFile
    name::Symbol
    size::NTuple{N,Int}
    varid::Int
    dimids::NTuple{N,Int}
    vsize::Int
end
