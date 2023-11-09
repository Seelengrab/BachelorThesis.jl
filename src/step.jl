using Libdl
using BenchmarkTools
using Logging

function build()
    inpath = joinpath(@__DIR__, "step.cpp")
    outpath = joinpath(@__DIR__, "step.so")
    if !isfile(inpath)
        @error "Cannot build shared object - source file is missing"
        exit(1)
    elseif !isfile(outpath)
        cmd = `g++ -g -O3 -march=native -std=c++17 -shared -fPIC -fopenmp $inpath -o $outpath`
        @info "Compiling shared C++ object"
        @debug "Command used to compile:" cmd
        run(cmd; wait=true)
    else
        @info "Nothing to build, shared object exists"
    end
end

build()

handle = dlopen(joinpath(@__DIR__, "step.so"))

const h_0nothreads = dlsym_e(handle, :step0_nothreads)
function v_0nothreads(r::Matrix{Float32}, d::Matrix{Float32}) 
    n = size(d, 1)
    @boundscheck size(d) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(d) == size(r) || throw(ArgumentError("Output matrix is not the same size as input matrix"))
    GC.@preserve r d ccall(h_0nothreads, Cvoid, (Ptr{Float32}, Ptr{Float32}, Cint), r, d, n)
end

Base.Cartesian.@nexprs 7 i -> begin
const h_{i-1} = dlsym_e(handle, Symbol("step", i-1))
function v_{i-1}(r::Matrix{Float32}, d::Matrix{Float32})
    n = size(d, 1)
    @boundscheck size(d) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(d) == size(r) || throw(ArgumentError("Output matrix is not the same size as input matrix"))
    GC.@preserve r d ccall(h_{i-1}, Cvoid, (Ptr{Float32}, Ptr{Float32}, Cint), r, d, n)
end
end

function checkEq(f_cpp, f_jl, n=4000)
    d_jl = rand(Float32, n, n)
    d_jl[1:(n+1):(n*n)] .= 0f0 # self-edges are free
    d_cpp = copy(d_jl)
    r1 = zeros(Float32, size(d_jl))
    r2 = zeros(Float32, size(d_jl))
    f_jl(r2, d_jl)
    f_cpp(r1, d_cpp)

    if !all(Splat(isapprox), zip(r1, r2))
        println("\npattern:")
        display(r2 .== r1)
        println("\ncpp")
        display(r1)
        println("\njl")
        display(r2)
        false
    else
        true
    end
end

function testMatrix(n)
    a = Matrix{Float32}(undef, n, n)
    a[:] .= 1:(n^2)
    a[1:(n+1):(n^2)] .= 0.0f0
    a
end

function v0noinboundsff!(r, d)
    n = size(d, 1)
    @boundscheck size(d) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(d) == size(r) || throw(ArgumentError("Output matrix is not the same size as input matrix"))

    for i in 1:n
        for j in 1:n
            v = Inf32
            for k in 1:n
                x = d[j, k]
                y = d[k, i]
                z = x + y
                v = min(v, z)
            end
            r[j, i] = v
        end
    end
end

function v0nothreads!(r, d)
    n = size(d, 1)
    @boundscheck size(d) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(d) == size(r) || throw(ArgumentError("Output matrix is not the same size as input matrix"))

    for i in 1:n
        @inbounds for j in 1:n
            v = Inf32
            for k in 1:n
                x = d[j, k]
                y = d[k, i]
                z = @fastmath x + y
                v = @fastmath min(v, z)
            end
            r[j, i] = v
        end
    end
end

using Base.Threads

function v0!(out, data)
    n = size(data, 1)
    @boundscheck size(data) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(data) == size(out) || throw(ArgumentError("Output matrix is not the same size as input matrix"))

    Threads.@threads for i in 1:n
        @inbounds for j in 1:n
            v = Inf32
            for k in 1:n
                x = data[j, k]
                y = data[k, i]
                v = @fastmath min(v, x + y)
            end
            out[i, j] = v
        end
    end
end

function v1!(out, data)
    n = size(data, 1)
    @boundscheck size(data) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(data) == size(out) || throw(ArgumentError("Output matrix is not the same size as input matrix"))

    tran = Matrix{Float32}(undef, n, n)
    Threads.@threads for col in 1:n
        @inbounds for row in 1:n
           tran[col,row] = data[row,col] 
        end
    end
    
    Threads.@threads for row in 1:n
        @inbounds for col in 1:n
            v = Inf32
            for block in 1:n
                x = data[block, col]
                y = tran[block, row]
                v = @fastmath min(v, x + y)
            end
            out[row, col] = v
        end
    end
end

using Base.Cartesian: @nexprs, @ntuple

function v2!(out, data_)
    n = size(data_, 1)
    @boundscheck size(data_) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(data_) == size(out) || throw(ArgumentError("Output matrix is not the same size as input matrix"))

    blocksize = 4
    nblocks = div(n + blocksize - 1, blocksize)
    colsize = nblocks*blocksize

    data = [ Inf32 for _ in 1:colsize, _ in 1:n ]
    tran = [ Inf32 for _ in 1:colsize, _ in 1:n ]
    Threads.@threads for row in 1:n
        @inbounds for col in 1:n
            data[col,row] = data_[col,row]
            tran[col,row] = data_[row,col]
        end
    end
    
    Threads.@threads for row in 1:n
        @inbounds for col in 1:n
            @nexprs 4 l -> v_l = Inf32
            for block in 1:blocksize:colsize
                @nexprs 4 blockidx -> begin
                    x = data[block+blockidx-1, col]
                    y = tran[block+blockidx-1, row]
                    v_blockidx = @fastmath min(v_blockidx, x + y)
                end
            end
            vt = @ntuple 4 v
            out[row, col] = @fastmath minimum(vt)
        end
    end
end

function v3!(out, data_)
    n = size(data_, 1)
    @boundscheck size(data_) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(data_) == size(out) || throw(ArgumentError("Output matrix is not the same size as input matrix"))

    blocksize = 8
    nblocks = div(n + blocksize - 1, blocksize)
    colsize = nblocks*blocksize

    data = Matrix{Float32}(undef, colsize, n)
    tran = Matrix{Float32}(undef, colsize, n)
    Threads.@threads for row in 1:n
        @inbounds for col in 1:colsize
            data[col,row] = col <= n ? data_[col,row] : Inf32
            tran[col,row] = col <= n ? data_[row,col] : Inf32
        end
    end
    
    Threads.@threads for row in 1:n
        @inbounds for col in 1:n
            # v_1, v_2, ..., v_8
            @nexprs 8 l -> v_l = Inf32
            for block in 1:blocksize:colsize
                @nexprs 8 blockidx -> begin
                    x = data[block+blockidx-1, col]
                    y = tran[block+blockidx-1, row]
                    v_blockidx = @fastmath min(v_blockidx, x + y)
                end
            end
            vt = @ntuple 8 v
            out[row, col] = @fastmath minimum(vt)
        end
    end
end

using SIMD
using SIMD: Vec

function v4!(out, data_)
    n = size(data_, 1) # matrix is square
    @boundscheck size(data_) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(data_) == size(out) || throw(ArgumentError("Output matrix is not the same size as input matrix"))

    vectorwidth = 8
    nvectors = div(n + vectorwidth - 1, vectorwidth)
    colsize = nvectors*vectorwidth # number of rows

    blockwidth = 3
    nblocks = div(n + blockwidth - 1, blockwidth)
    rowsize = nblocks*blockwidth # number of columns

    data = Matrix{Float32}(undef, colsize, rowsize)
    tran = Matrix{Float32}(undef, colsize, rowsize)
    Threads.@threads for row in 1:rowsize
        @inbounds for col in 1:n
            data[col,row] = row <= n ? data_[col,row] : Inf32
            tran[col,row] = row <= n ? data_[row,col] : Inf32
        end
    end
    @inbounds for row in 1:rowsize
        for col in n+1:colsize
            data[col,row] = Inf32
            tran[col,row] = Inf32
        end
    end

    Threads.@threads for row in 1:blockwidth:n
        @inbounds for col in 1:blockwidth:n
            # v_1_1_1, v_1_1_2, ..., v_2_1_1, ..., v_3_3_8
            @nexprs 3 l -> begin
            @nexprs 3 k -> begin
                v_k_l = Vec(@ntuple 8 _ -> Inf32)
            end
            end

            for block in 1:vectorwidth:colsize
                # x_1_1, ..., x_3_8
                # y_1_1, ..., y_3_8
                @nexprs 3 k -> y_k = Vec(@ntuple 8 i -> tran[block+(i-1), row+(k-1)])
                @nexprs 3 k -> x_k = Vec(@ntuple 8 i -> data[block+(i-1), col+(k-1)])

                @nexprs 3 k -> begin
                @nexprs 3 l -> begin
                    v_k_l = @fastmath min(v_k_l, x_k + y_l)
                end
                end
            end
            
            @nexprs 3 l -> begin
            @nexprs 3 k -> begin
                out_row = row+(l-1)
                out_col = col+(k-1)
                if out_row <= n && out_col <= n
                    out[out_row, out_col] = minimum(v_k_l)
                end
            end
            end
        end
    end
end

using Base: setindex

swap4(nt::T) where T = shufflevector(nt, Val((4, 5, 6, 7, 0, 1, 2, 3)))
swap2(nt::T) where T = shufflevector(nt, Val((2, 3, 0, 1, 6, 7, 4, 5)))
swap1(nt::T) where T = shufflevector(nt, Val((1, 0, 3, 2, 5, 4, 7, 6)))

function v5!(out, data_)
    n = size(data_, 1) # matrix is square
    @boundscheck size(data_) == (n, n)  || throw(ArgumentError("Input matrix is not square"))
    @boundscheck size(data_) == size(out) || throw(ArgumentError("Output matrix is not the same size as input matrix"))

    blocksize = 8
    nblocks = div(n + blocksize - 1, blocksize) # number of vertical blocks in data_
    colsize = n*blocksize # save n*blocksize elements per column

    data = Matrix{Float32}(undef, colsize, nblocks)
    tran = Matrix{Float32}(undef, colsize, nblocks)
    Threads.@threads for row in 1:nblocks
        @inbounds for col in 1:n
            for jb in 1:blocksize
                j = (col-1)*blocksize + jb
                i = (row-1)*blocksize + jb
                data[j, row] = i <= n ? data_[i, col] : Inf32
                tran[j, row] = i <= n ? data_[col, i] : Inf32
            end
        end
    end

    Threads.@threads for colidx in 1:nblocks
        @inbounds for rowidx in 1:nblocks
            # v_1, v_2, ..., v_8
            v = @ntuple 8 l -> Vec(@ntuple 8 _ -> Inf32)

            for block in 1:blocksize:colsize
                a_0 = Vec(@ntuple 8 blockidx -> data[block+blockidx-1, colidx])
                b_0 = Vec(@ntuple 8 blockidx -> tran[block+blockidx-1, rowidx])
                a_4 = swap4(a_0)
                a_2 = swap2(a_0)
                a_6 = swap2(a_4)
                b_1 = swap1(b_0)
                @nexprs 4 l -> begin
                @nexprs 2 k -> begin
                    z = @fastmath a_{2*(l-1)} + b_{k-1}
                    res = @fastmath min(v[2*(l-1)+k], z)
                    v = setindex(v, res, 2*(l-1)+k)
                end
                end
            end

            @nexprs 4 idx -> v = setindex(v, swap1(v[2*idx]), 2*idx)
            
            for col_block in 1:blocksize
                for row_block in 1:blocksize
                    row = row_block + (rowidx-1)*blocksize
                    col = col_block + (colidx-1)*blocksize
                    if row <= n && col <= n
                        idx = xor(row_block-1, col_block-1)
                        el = v[idx + 1][row_block]
                        out[col, row] = el
                    end
                end
            end
        end
    end
end


function v6!(r, d, n)

end


function v7!(r, d, n)

end

####
# Benchmarking code
####

function setupBenchmarks()
    BENCHES = BenchmarkGroup()
    BENCHES["jl"] = BenchmarkGroup()
    BENCHES["cpp"] = BenchmarkGroup()

    BENCHES["jl"][-2]  = @benchmarkable v0noinboundsff!(r, d) setup=(n=4000;r=zeros(Float32,n,n);d=rand(Float32,n,n);d[1:(n+1):(n*n)].=0f0) evals=1 seconds=600
    BENCHES["jl"][-1]  = @benchmarkable v0nothreads!(r, d) setup=(n=4000;r=zeros(Float32,n,n);d=rand(Float32,n,n);d[1:(n+1):(n*n)].=0f0) evals=1 seconds=600
    BENCHES["cpp"][-1] = @benchmarkable v_0nothreads(r, d) setup=(n=4000;r=zeros(Float32,n,n);d=rand(Float32,n,n);d[1:(n+1):(n*n)].=0f0) evals=1 seconds=600

    jl_name(i) = if parse(Int, i) == -2
        "v0noinboundsff!"
    elseif parse(Int, i) == -1
        "v0nothreads!"
    else
        "v$(i)!"
    end

    cpp_name(i) = if parse(Int, i) == -1
        "v_0nothreads"
    else
        "v_$i"
    end

    for i in 0:5 # 6 & 7 are not implemented
        f_jl  = eval(Symbol("v", i, "!"))
        f_cpp = eval(Symbol("v_", i))
        BENCHES["jl"][i]  = @benchmarkable $f_jl(r, d) setup=(n=4000;r=zeros(Float32,n,n);d=rand(Float32,n,n);d[1:(n+1):(n*n)].=0f0) evals=1 seconds=60
        BENCHES["cpp"][i] = @benchmarkable $f_cpp(r, d) setup=(n=4000;r=zeros(Float32,n,n);d=rand(Float32,n,n);d[1:(n+1):(n*n)].=0f0) evals=1 seconds=60
    end

    BENCHES["scaling"] = BenchmarkGroup()
    BENCHES["scaling"]["v0"] = BenchmarkGroup()
    BENCHES["scaling"]["v1"] = BenchmarkGroup()

    scaling_ns = (100, 160, 250, 400, 630, 1000, 1600, 2500, 4000, 6300)
    for i in scaling_ns
        BENCHES["scaling"]["v0"][i] = @benchmarkable v0!(r, d) setup=(n=$i;r=zeros(Float32,n,n);d=rand(Float32,n,n);d[1:(n+1):(n*n)].=0f0) evals=1 seconds=60
        BENCHES["scaling"]["v1"][i] = @benchmarkable v1!(r, d) setup=(n=$i;r=zeros(Float32,n,n);d=rand(Float32,n,n);d[1:(n+1):(n*n)].=0f0) evals=1 seconds=60
    end

    BENCHES
end
