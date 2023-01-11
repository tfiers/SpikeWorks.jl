
abstract type NeuronModel end
abstract type NeuronModel_Vars end
abstract type NeuronModel_DₜVars end

vars(n::NeuronModel) = n.vars
Dₜvars(n::NeuronModel) = n.Dₜvars

function update_derivatives! end
function has_spiked end
function on_self_spike! end
