using IntelITT

@assert IntelITT.available()

include("step.jl")

n = 2000
d = rand(Float32, n, n)
r_jl = Matrix{Float32}(undef, n, n)
r_2 = Matrix{Float32}(undef, n, n)

println(ARGS)
if ARGS[1] == "jl"
v5!(r_2, d, n)
IntelITT.resume()
v5!(r_jl, d, n)
else
IntelITT.resume()
v_5(r_jl, d, n)
end
IntelITT.pause()
