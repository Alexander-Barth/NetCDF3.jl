mutable struct File{TIO <: IO, TV}
    io::TIO
    write::Bool
    version_byte::UInt8
    recs::Int32
    dim::OrderedDict{Symbol,Int}
    _dimid::OrderedDict{Int,Int}
    attrib::OrderedDict{Symbol,Any}
    start::Vector{Int64}
    vars::Vector{TV}
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
