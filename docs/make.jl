# To be run from the project root:
# $ julia docs/make.jl
#
# For faster rebuilds (with Revise for when working on docstrings):
# julia> ENV["JULIA_FIREWORK_MKDOCS_INSTALL"] = false; using Revise
# julia> include("docs/make.jl")

@assert pwd() == dirname(@__DIR__)  # Check if we're in parent dir
using Pkg
Pkg.activate("docs")

if get(ENV, "JULIA_FIREWORK_MKDOCS_INSTALL", "true") == "true"
    Pkg.add(url="https://github.com/JuliaDocs/Documenter.jl/", rev="ef4412f")
    #   To get 'repo link in navbar' feature (https://github.com/JuliaDocs/Documenter.jl/pull/1254)
    Pkg.develop(path=".")
end

using Documenter
using Firework
println("Calling `makedocs`")
makedocs(
    sitename = "Firework",
    modules = [Firework],
    doctest = false,         # Done in runtests.jl
)
