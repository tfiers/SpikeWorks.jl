module SpikeWorks

using Base: RefValue
# ↪ `Ref` is abstract, so bad for perf as struct field. `RefValue` is the concrete subtype.
#    As this is not exported from Base, nor documented, it's not public api and can thus
#    change. Better would thus be to `MyStruct{T<:Ref{Int}} myfield::T`,
#    instead of `MyStruct myfield::RefValue{Int}`, as it is now.

using Printf

using ComponentArrays: ComponentArrays, ComponentVector, Axis



using Base.Meta: isexpr
include("globalmacros.jl")
export @constants,  # alt name: @consts. but no, tongue twister.
       @typed,
       @export_all  # alt name ideas: @exportall. @batchexport.  (cannot have @export, alas).


using Test: @test
include("checkmacro.jl")
export @check


using Crayons
include("display.jl")


include("units.jl")


include("EI_mix.jl")
export EIMix,
       groupsizes


using Distributions
# ↪ Don't `@reexport Distributions`: this macro somehow also exports our own `LogNormal`,
#   creating a conflict.
include("distributions.jl")
# ↪ Don't export LogNormal, to not conflict with Distributions.jl
#   Instead, to use our parametrization (with median and g), use `SpikeWorks.LogNormal`.


include("misc.jl")
export to_timesteps


include("counter.jl")


include("model.jl")
export NeuronModel,
       Nto1Input,
       Nto1System,
       Spike,
       source


using .Units: second
include("sim.jl")
export simulate


include("poisson.jl")
export poisson_spikes,
       poisson_SpikeTrain


# include("eqparse.jl");    export @eqs
# include("latex.jl");      export show_eqs


end # module
