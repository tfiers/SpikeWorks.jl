# Looking at test/sim.jl, wondering about if function signatures could be auto generated
# from function body..

izh!(D; v, u, gₑ, gᵢ, C, Eᵢ, Eₑ, a, b, k, vᵣ, vₗ, vₜ, τ) = begin
    # Conductance-based synaptic current
    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
    # Izhikevich 2D system: v and adaptation
    D.v = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C
    D.u = a*(b*(v-vᵣ) - u)
    # Synaptic conductance decay
    D.gₑ = -gₑ / τ
    D.gᵢ = -gᵢ / τ
end
has_spiked(; v, vₛ) = (v ≥ vₛ)
on_self_spike!(vars; vᵣ, Δu) = begin
    vars.v = vᵣ
    vars.u += Δu
end
# On-spike-arrival functions:
fₑ!(vars; Δgₑ) = (vars.gₑ += Δgₑ)
fᵢ!(vars; Δgᵢ) = (vars.gᵢ += Δgᵢ)


# ..
# versus
# ..


izh! = @f begin
    # Conductance-based synaptic current
    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
    # Izhikevich 2D system: v and adaptation
    D.v = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C
    D.u = a*(b*(v-vᵣ) - u)
    # Synaptic conductance decay
    D.gₑ = -gₑ / τ
    D.gᵢ = -gᵢ / τ
end
has_spiked = @f (v ≥ vₛ)
on_self_spike! @f begin
    vars.v = vᵣ
    vars.u += Δu
end
# On-spike-arrival functions:
fₑ! = @f (vars.gₑ += Δgₑ)
fᵢ! = @f (vars.gᵢ += Δgᵢ)


# Cool (a middle ground between user having to give full verbose signatures and full weird
# DSL).
# But now these `vars.` and `D.` is kinda grating huh.
# myeh, suppose we could go dsl here.
# I.e. look at what's on lhs. :).

izh! = @f begin
    # Conductance-based synaptic current
    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
    # Izhikevich 2D system: v and adaptation
    dv/dt = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C
    du/dt = a*(b*(v-vᵣ) - u)
    # Synaptic conductance decay
    dgₑ/dt = -gₑ / τ
    dgᵢ/dt = -gᵢ / τ
end
has_spiked = @f (v ≥ vₛ)
on_self_spike! @f begin
    v = vᵣ
    u += Δu
end
# On-spike-arrival functions:
fₑ! = @f (gₑ += Δgₑ)
fᵢ! = @f (gᵢ += Δgᵢ)

# These functions, btw, would be nice inlined in the sim loop.
# No `getproperty` to get the parameters each time, no call stack frame,
# no kwarg binding.

# On the two types of Poisson input.
# would it be faster if there was just one update function,
# with an if block, and somehow these inputs have a variable :type.
#
# Might not be general.
# but in this case it would be true that model struct is fully concrete:
# model.inputs::Vector{PoissonInput{typeof(f!)}}
#
on_input_spike! = @f
    if     (input_type == :exc)  (gₑ += Δgₑ)
    elseif (input_type == :inh)  (gᵢ += Δgᵢ) end
#
# and then sth like
inputs = PoissonInput.(rates, T, on_input_spike!)
inputs.exc.type == :exc
# eh no that's ugly (the duplication).
# but ye, that's the idea.
