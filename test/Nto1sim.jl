using Firework
using Firework.Units
using Firework: LogNormal

# Parameters
@typed begin
    # Izhikevich neuron
    C  =  100    * pF
    k  =    0.7  * (nS/mV)
    vₗ = - 60    * mV
    vₜ = - 40    * mV
    a  =    0.03 / ms
    b  = -  2    * nS
    vₛ =   35    * mV
    vᵣ = - 50    * mV
    Δu =  100    * pA
    # Synapses
    Eₑ =   0 * mV
    Eᵢ = -80 * mV
    τ  =   7 * ms
    # Integration
    Δt = 0.1ms
    T  = 10seconds
end

# Conductance-based Izhikevich neuron
g_izh_neuron = NeuronModel(

    # Simulated variables, and their initial values
    (
        v   =  vᵣ,
        u   = 0 * pA,
        gₑ  = 0 * nS,
        gᵢ  = 0 * nS,
    ),

    # Set time derivatives (Δ) of simulated vars
    (Δ, vars) -> begin
        @unpack v, u, gₑ, gᵢ = vars

        # Conductance-based synaptic current
        Iₛ = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
        # Izhikevich 2D system
        Δ.v = (k*(v-vₗ)*(v-vₜ) - u - Iₛ) / C  # Membrane potential
        Δ.u = a*(b*(v-vᵣ) - u)                # Adaptation current
        # Synaptic conductance decay
        # (gₑ is sum over all exc synapses, gᵢ over all inh)
        Δ.gₑ = -gₑ / τ
        Δ.gᵢ = -gᵢ / τ
    end,

    # Spike condition
    (vars) -> (vars.v ≥ vₛ),

    # On-self-spike
    (vars) -> begin
        vars.v = vᵣ
        vars.u += Δu
    end
)


# Inputs

@typed begin
    Nₑ = 40
    Nᵢ = 10
    N = Nₑ + Nᵢ
    Δgₑ = 60nS / Nₑ
    Δgᵢ = 60nS / Nᵢ
end

# i = spiketrain ID / number
neuron_type(i) = if (i ≤ Nₑ)  :exc
                 else         :inh
                 end

on_spike_arrival(pre, post) =
    if neuron_type(pre) == :exc
        post.gₑ += Δgₑ
    else
        post.gᵢ += Δgᵢ
    end

# Firing rates λ for the Poisson inputs
fr_distr = LogNormal(median = 4Hz, g = 2)
λs = rand(fr_distr, N)
spiketrains = [poisson_spiketrain(λ, T) for λ in λs]

m = Nto1Model(spiketrains, on_spike_arrival, g_izh_neuron)


using Firework: CVector
# ↪ For terser error msgs: unqualified names

# s = sim(m, init, params, T, Δt)
s = init_sim(init, params, T, Δt)
s = step!(s, m)
