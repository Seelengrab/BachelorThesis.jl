import Pkg
using Logging
using Mmap

@info "Activating thesis environment"
Pkg.activate(@__DIR__)
@info "Instantiating packages"
Pkg.instantiate()

using Documenter
using DocumenterCitations

include("style.jl")

function builddocs(clear=false,platform="pdf")
    clear && rm(joinpath(@__DIR__, "build"), force=true, recursive=true)
    @info "Building $platform"
    format = if platform != "html"
        Documenter.LaTeX(platform=platform)
    else
        Documenter.HTML(
            prettyurls = get(ENV, "CI", nothing) == true,
            ansicolor = true
        )
    end

    bib = CitationBibliography(
        joinpath(@__DIR__, "src", "refs.bib");
        style=:thesis
    )

    makedocs(
        sitename="Performance Optimization in Julia",
        format = format,
        remotes = nothing,
        pages = [ "index.md" ],
        plugins=[bib]
    )
end

if !isinteractive()
    clear = "clear" in ARGS
    platform = if "pdf" in ARGS
        "native"
    elseif "tex" in ARGS
        "none"
    else
        "html"
    end
    builddocs(clear,platform)
end

if isdefined(Main, :LiveServer)
    builddocs(false,"html")
end
