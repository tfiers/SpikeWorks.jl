using Firework
using Firework: SpikingInput, SpikeFeed, CVector, SimState, LogNormal
using Firework.Units

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
    # Inputs
    Nₑ = 40
    Nᵢ = 10
    N = Nₑ + Nᵢ
    Δgₑ = 60nS / Nₑ
    Δgᵢ = 60nS / Nᵢ
    # Integration
    Δt = 0.1ms
    T  = 10seconds
end

# Variables and their initial values
@typed begin
    v      = vᵣ
    u      = 0 * pA
    gₑ     = 0 * nS
    gᵢ     = 0 * nS
    I_syn  = 0 * nA
    # # Gathering all..
    # vars = CVector(; v, u, gₑ, gᵢ)
    # # ..to get time derivatives
    # Δ = zero(vars ./ Δt)
    # as api:
    Δ = derivatives(; v, u, gₑ, gᵢ)
end

izh() = begin
    # Conductance-based synaptic current
    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
    # Izhikevich 2D system
    Δ.v = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C  # Membrane potential
    Δ.u = a*(b*(v-vᵣ) - u)                   # Adaptation current
    # Synaptic conductance decay
    # (gₑ is sum over all exc synapses)
    Δ.gₑ = -gₑ / τ
    Δ.gᵢ = -gᵢ / τ
end
has_spiked() = (v ≥ vₛ)
on_self_spike() = begin
    v = vᵣ
    u += Δu
end

neuron_type(i) = if (i ≤ Nₑ)  :exc
                 else         :inh
                 end
on_spike_arrival(from) =
    if (neuron_type(from) == :exc)  gₑ += Δgₑ
    else                            gᵢ += Δgᵢ
    end

# Poisson inputs firing rates λ
fr_distr = LogNormal(median = 4Hz, g = 2)
λ = rand(fr_distr, N)
spiketimes = poisson_spikes.(λ, T)

# to go in lib:
spikesources = similar.(spiketimes)
for (srcID, array) in enumerate(spikesources)
    array .= srcID
end
spiketimes_merged   = reduce(vcat, spiketimes)
spikesources_merged = reduce(vcat, spikesources)
order = sortperm(spiketimes_merged)
permute!(spiketimes_merged,   order)
permute!(spikesources_merged, order)

m = Model(izh, has_spiked, on_self_spike, inputs)

# s = sim(m, init, params, T, Δt)
s = init_sim(init, params, T, Δt)
s = step!(s, m)
