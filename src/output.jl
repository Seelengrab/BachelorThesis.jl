length(ARGS) != 1 && error("Need to take the function name as sole argument!")
@show ARGS

include("step.jl")

using InteractiveUtils

const func = eval(Symbol(only(ARGS)))
@show func
open("code_typed_$func", "w+") do f
    redirect_stdout(f) do
        code_typed(func, (Matrix{Float32}, Matrix{Float32})) |> only |> print
    end
end
open("code_llvm_$func", "w+") do f
    code_llvm(f, func, (Matrix{Float32}, Matrix{Float32}); optimize=true)
end
open("code_native_$func", "w+") do f
    code_native(f, func, (Matrix{Float32}, Matrix{Float32}); syntax=:intel)
end