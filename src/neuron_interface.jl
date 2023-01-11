
abstract type Neuron end
abstract type NeuronVars end
abstract type NeuronVarDerivatives end

vars(n::Neuron) = n.vars
derivatives(n::Neuron) = n.Dₜvars

varnames(n::Neuron) = fieldnames(typeof(vars(n)))

# Allow access to simulated variables as `neuron[:v]`.
# Shortens `getproperty(vars(neuron), x)` → `neuron[x]`
Base.getindex(v::Neuron, s::Symbol) = vars(v)[s]
Base.getindex(v::NeuronVars, s::Symbol) = getfield(v, s)
Base.getindex(v::NeuronVarDerivatives, s::Symbol) = getfield(v, s)

function update_derivatives! end
function has_spiked end
function on_self_spike! end
function vars_to_record end

eulerstep!(n::Neuron, Δt) = let (; vars, Dₜvars) = n
    update_derivatives!(n)
    for i in varnames(n)
        vars[i] += Dₜvars[i] * Δt
    end
end


# Fall-through definitions and defaults
#
# User may use time; but they don't have to
update_derivatives!(n::Neuron, t) = update_derivatives!(n)
has_spiked(n::Neuron, t) = has_spiked(n)
#
# Change nothing by default
on_self_spike!(n::Neuron) = n
#
# Record nothing by default
vars_to_record(::Neuron) = Symbol[]
