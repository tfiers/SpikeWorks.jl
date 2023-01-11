
abstract type Neuron end
abstract type Vars end

vars(n::Neuron) = n.vars
derivatives(n::Neuron) = n.Dₜvars

varnames(n::Neuron) = fieldnames(typeof(vars(n)))

# Allow access to simulated variables as `neuron[:v]`.
# Shortens `getproperty(vars(neuron), x)` → `neuron[x]`
Base.getindex(n::Neuron, s::Symbol)     = vars(n)[s]
Base.setindex!(n::Neuron, x, s::Symbol) = (vars(n).s = v)
Base.getindex(v::Vars, s::Symbol)     = getfield(v, s)
Base.setindex!(v::Vars, x, s::Symbol) = setfield!(v, s, x)

function update_derivatives! end
function has_spiked end
function on_self_spike! end

eulerstep!(n::Neuron, Δt) = let (; vars, Dₜvars) = n
    update_derivatives!(n)
    for i in varnames(n)
        vars[i] += Dₜvars[i] * Δt
    end
    return n
end

# Fall-through definitions and defaults
#
# User may use time; but they don't have to
update_derivatives!(n::Neuron, t) = update_derivatives!(n)
has_spiked(n::Neuron, t) = has_spiked(n)
#
# Change nothing by default
on_self_spike!(n::Neuron) = n
