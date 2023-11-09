using TikzGraphs, TikzPictures, Graphs

function typeLattice()
	g = DiGraph(12)
	add_edge!(g, 1, 2)
	add_edge!(g, 2, 3)
	add_edge!(g, 2, 9)
	add_edge!(g, 11, 5)
	add_edge!(g, 3, 4)
	add_edge!(g, 3, 7)
	add_edge!(g, 7, 5)
	add_edge!(g, 4, 5)
	add_edge!(g, 1, 6)
	add_edge!(g, 6, 12)
	add_edge!(g, 12, 5)
	add_edge!(g, 1, 8)
	add_edge!(g, 8, 11)
	add_edge!(g, 9, 5)
	add_edge!(g, 1, 10)
	add_edge!(g, 10, 5)
	t = TikzGraphs.plot(g, ["Any", 
							"AbstractArray\\{Int64, 1\\}", 
							"DenseArray\\{Int64, 1\\}", 
							"Array\\{Int64, 1\\}", 
							"Union\\{\\}", 
							"AbstractString", 
							"...", 
							"Number", 
							"...", 
							"...", 
							"...", 
							"..."], node_style="outer sep=8pt")
end

function compilegraph()
    nodes = [
        "Source Code",
        "Lexing, Parsing & Lowering",
        "Optimization Passes",
        "Julia Abstract Interpretation",
        "LLVM-IR Optimization & Compilation",
        "Execution" ]
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 3, 4)
    add_edge!(g, 4, 5)
    add_edge!(g, 5, 6)
    add_edge!(g, 6, 1)
    add_edge!(g, 6, 2)
    add_edge!(g, 6, 3)
    add_edge!(g, 6, 4)
    g = Graph(length(nodes))
    t = TikzGraphs.plot(g, nodes, node_style="draw, rounded corners")
end

# keep synchronized with step.jl
const scaling_ns = (100, 160, 250, 400, 630, 1000, 1600, 2500, 4000, 6300)

using CairoMakie
using Printf

function prepare_data(namefunc, data)
    pairs = [namefunc(k) => v for (k,v) in data]
    function ltnameval(x,y)
        'f' in x[1] && return true
        'f' in y[1] && return false
        if occursin('0', x[1]) && occursin('0', y[1])
            if length(x[1]) >= length(y[1])
                true
            else
                x[2] < y[2]
            end
        else
            x < y
        end
    end
    sort!(pairs, lt = ltnameval)
end

function theoretical_time(n, cores=2.0, ports=2.0, ops=8.0, hz=3_200_000_000)
# 2 cores * 2 ports/core * 8 ops/cycle * 3_200_000_000 cycles/second * 1 second
# the cycles per second is with turbo on both cores, according to 
# https://en.wikichip.org/w/images/b/bd/6th_Gen_Intel%C2%AE_Core%E2%84%A2_processor_family_and_Intel%C2%AE_Xeon%C2%AE_processors_Factsheet.pdf
    ops_per_s = (cores * ports * ops * hz)
    total_ops = 2*(n^3.0)
    total_ops/ops_per_s
end

col_jl() = :green
col_cpp() = :blue

function plotV0Results(res)
    # the minimum is a stable indicator of the best possible performance we can get
    jl = prepare_data(jl_name, res["jl"] |> minimum |> time)
    cpp = prepare_data(cpp_name, res["cpp"] |> minimum |> time)
    color = [col_jl(), col_jl(), col_jl(), col_cpp(), col_cpp()]

    timedata = last.([jl[1:3]..., cpp[1:2]...]) ./ 1e9
    dodge = [1,1,1,2,2]
    plotidx = [1,2,3,2,3]

    f = Figure()
    ax = Axis(f[1,1], xticks=(1:3, ["no macros", "@inbounds &\n @fastmath vs.\nC++ Baseline", "@threads vs.\nOpenMP"]), title="Walltime V0 (lower is better)", ytickformat=tickfmt, xticklabelrotation=45.0)
    barplot!(ax, plotidx, timedata; dodge, color)
    axislegend(ax, [PolyElement(polycolor=col_jl()), PolyElement(polycolor=col_cpp())], ["Julia", "C++"], tellheight=false, tellwidth=false,
                    margin=(10,10,10,10), position=:rt)

    f
end

function plotV1Scaling(res, scale=log2)
    v0 = sort!(map(prepare_data(string, res["v0"] |> minimum |> time)) do (k,v)
        _k = parse(Int, k)
        _k => (2*_k^3)/v
    end)
    v1 = sort!(map(prepare_data(string, res["v1"] |> minimum |> time)) do (k,v)
        _k = parse(Int, k)
        _k => (2*_k^3)/v
    end)

    v0 = last.(v0) ./ last(first(v0))
    v1 = last.(v1) ./ last(first(v1))

    ytickformat(values) = map(values) do v
        @sprintf "%1.1fx" v
    end

    f = Figure()
    ax = Axis(f[1,1], xticks=(1:length(scaling_ns), collect(string.(scaling_ns))), title="Scaling (higher is better)", yscale=scale,
                xlabel="Problemsize n", ylabel="Relative Performance to n=100", subtitle="GFLOPS(n) / GFLOPS(100)", ytickformat=ytickformat)
    lines!(ax, v1; color=:orange, fill_to=0.001)
    lines!(ax, v0; color=:blue, fill_to=0.001)
    axislegend(ax, [PolyElement(polycolor=:blue), PolyElement(polycolor=:orange)], ["v0!", "v1!"], tellheight=false, tellwidth=false,
                    margin=(10,10,10,10), position=:rt)

    f    
end

tickfmt(values) = map(values) do v
    @sprintf "%3.2fs" v # like xxx.yys
end

jl_name(s::String) = jl_name(parse(Int, s))
cpp_name(s::String) = cpp_name(parse(Int, s))

jl_name(i) = if i == -2
    "v0noinboundsff!"
elseif i == -1
    "v0nothreads!"
else
    "v$(i)!"
end

cpp_name(i) = if i == -1
    "v_0nothreads"
else
    "v_$i"
end

function plotV1to3(res)
    jl = prepare_data(jl_name, res["jl"] |> minimum |> time)[4:6]
    cpp = prepare_data(cpp_name, res["cpp"] |> minimum |> time)[3:5]
    colors = [col_jl(), col_cpp()]

    f = Figure()
    ax = Axis(f[1,1], xticks=(1:3, [jl_name(i) for i in 1:3]), title="Walltime", subtitle="lower is better", ylabel="Seconds")

    plotidx = repeat(1:3; outer=2)
    timedata = last.([jl..., cpp...]) ./ 1e9
    dodge = repeat(1:2; inner=3)
    color = repeat(colors; inner=3)
    rt = barplot!(ax, plotidx, timedata; dodge, color)
    axislegend(ax, [PolyElement(polycolor=colors[i]) for i in 1:2], ["Julia", "C++"], tellheight=false, tellwidth=false,
                    margin=(10,10,10,10), position=:rt)

    problem_size = 4000
    # convert time to FLOPS
    flopdata = (2.0*problem_size^3.0)./(timedata)
    flopfmt(values) = map(values) do v
        @sprintf "%3.1f" v / 1e9 # so the GFLOPS are like xxx.yy
    end

    # barplot for FLOPS
    ax2 = Axis(f[1,2], xticks=(1:3, [jl_name(string(i)) for i in 1:3]), title="GFLOPS", subtitle="higher is better", ytickformat=flopfmt)
    barplot!(ax2, plotidx, flopdata; dodge, color)

    f
end

function plotV3toV4(res)
    jl = prepare_data(jl_name, res["jl"] |> minimum |> time)[6:7]
    cpp = prepare_data(cpp_name, res["cpp"] |> minimum |> time)[5:6]
    colors = [col_jl(), col_cpp()]

    f = Figure()
    ax = Axis(f[1,1], xticks=(3:4, [jl_name(i) for i in 3:4]), title="Walltime", subtitle="lower is better", ylabel="Seconds")
    plotidx = repeat(3:4; outer=2)
    timedata = last.([jl..., cpp...]) ./ 1e9
    dodge = repeat(1:2; inner=2)
    color = repeat(colors; inner=2)
    rt = barplot!(ax, plotidx, timedata; dodge, color)

    axislegend(ax, [PolyElement(polycolor=colors[i]) for i in 1:2], ["Julia", "C++"], tellheight=false, tellwidth=false,
                    margin=(10,10,10,10), position=:rt)

    problem_size = 4000
    # convert time to FLOPS
    flopdata = (2.0*problem_size^3.0)./(timedata)
    flopfmt(values) = map(values) do v
        @sprintf "%3.1f" v / 1e9 # so the GFLOPS are like xxx.yy
    end

    # barplot for FLOPS
    ax2 = Axis(f[1,2], xticks=(3:4, [jl_name(string(i)) for i in 3:4]), title="GFLOPS", subtitle="higher is better", ytickformat=flopfmt)
    barplot!(ax2, plotidx, flopdata; dodge, color)

    f
end

function plotAllBenchmarkResults(res)
    # the minimum is a stable indicator of the best possible performance we can get
    jl = prepare_data(jl_name, res["jl"] |> minimum |> time)
    cpp = prepare_data(cpp_name, res["cpp"] |> minimum |> time)
    colors = [col_jl(), col_cpp()]

    # the index i to place the element that's at array position x
    plotidx = repeat(1:7; outer=2)
    # ignore the non-@fastmath version
    deleteat!(jl, 1)
    timedata = last.([jl..., cpp...]) ./ 1e9
    dodge = repeat(1:2; inner=7)
    color = repeat(colors; inner=7)

    f = Figure()

    # barplot for walltime
    ax = Axis(f[1,1], xticks=(1:7, [jl_name(string(i)) for i in -1:5]), title="Walltime (lower is better)", ytickformat=tickfmt, xticklabelrotation=45.0)
    rt = barplot!(ax, plotidx, timedata; dodge, color)
    axislegend(ax, [PolyElement(polycolor=colors[i]) for i in 1:2], ["Julia", "C++"], tellheight=false, tellwidth=false,
                    margin=(10,10,10,10), position=:rt)

    # The size we looked at for benchmarking all functions
    problem_size = 4000
    # convert time to FLOPS
    flopdata = (2.0*problem_size^3.0)./(timedata)
    flopfmt(values) = map(values) do v
        @sprintf "%3.2f" v / 1e9 # so the GFLOPS are like xxx.yy
    end

    # barplot for FLOPS
    ax2 = Axis(f[1,2], xticks=(1:7, [jl_name(string(i)) for i in -1:5]), title="GFLOPS (higher is better)", ytickformat=flopfmt, xticklabelrotation=45.0)
    barplot!(ax2, plotidx, flopdata; dodge, color)
    theo_flop = (2.0*problem_size^3.0)/theoretical_time(problem_size)
    ablines!(ax2, theo_flop, 0.0)
    text!(ax2, 6, theo_flop, text="Theoretical Maximum", align=(:right, :top))

    f
end

function saveFigs(res, postfix="")
    v0plot = plotV0Results(res)
    v1scale = plotV1Scaling(res["scaling"])
    v1to3plot = plotV1to3(res)
    v3and4plot = plotV3toV4(res)
    allplot = plotAllBenchmarkResults(res)

    s = isempty(postfix) ? "" : '_'*postfix
    CairoMakie.save("figs/v0$s.png", v0plot; px_per_unit=3)
    CairoMakie.save("figs/v1_scaling$s.png", v1scale; px_per_unit=3)
    CairoMakie.save("figs/v1tov3_comparison$s.png", v1to3plot; px_per_unit=3)
    CairoMakie.save("figs/v3tov4_comparison$s.png", v1to3plot; px_per_unit=3)
    CairoMakie.save("figs/all_versions$s.png", allplot; px_per_unit=3)
    println("Done saving figures!")
    nothing
end
