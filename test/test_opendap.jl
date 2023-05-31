using HTTP


# https://datatracker.ietf.org/doc/html/rfc1832


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
