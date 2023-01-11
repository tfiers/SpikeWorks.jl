
abstract type Neuron end
abstract type NeuronVars end
abstract type NeuronVarDerivatives end

vars(n::Neuron) = n.vars
derivatives(n::Neuron) = n.Dₜvars

varnames(n::Neuron) = fieldnames(typeof(vars(n)))

function update_derivatives! end
function has_spiked end
function on_self_spike! end

to_record(::NeuronModel) = Symbol[]

eulerstep!(n::Neuron, Δt) = let (; vars, Dₜvars) = n
    update_derivatives!(n)
    for i in varnames(n)
        vars[i] += Dₜvars[i] * Δt
    end
end
