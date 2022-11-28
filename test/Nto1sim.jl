using SpikeLab
using SpikeLab: SpikingInput, SpikeFeed, CVector, SimState, LogNormal
using SpikeLab.Units

# Parameters
# ‾‾‾‾‾‾‾‾‾‾
# Izhikevich neuron
const C  =  100    * pF
const k  =    0.7  * (nS/mV)
const vₗ = - 60    * mV
const vₜ = - 40    * mV
const a  =    0.03 / ms
const b  = -  2    * nS
const vₛ =   35    * mV
const vᵣ = - 50    * mV
const Δu =  100    * pA
# Synapses
const Eₑ =   0 * mV
const Eᵢ = -80 * mV
const τ  =   7 * ms
# Inputs
const Nₑ = 40
const Nᵢ = 10
const N = Nₑ + Nᵢ
const Δgₑ = 60nS / Nₑ
const Δgᵢ = 60nS / Nᵢ
# Integration
const Δt = 0.1ms
const T  = 10seconds


# Variables and their initial values
# ‾‾‾‾‾‾‾‾‾
v     ::Float64   = vᵣ
u     ::Float64   = 0 * pA
gₑ    ::Float64   = 0 * nS
gᵢ    ::Float64   = 0 * nS
I_syn ::Float64   = 0 * nA
# Derivatives
const vars = CVector(; v, u, gₑ, gᵢ)
const Δ = zero(vars ./ Δt)

izh() = begin
    # Conductance-based synaptic current
    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
    # Izhikevich 2D system: v and adaptation
    Δ.v = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C
    Δ.u = a*(b*(v-vᵣ) - u)
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
    if (neuron_type(from) == :exc)  gₑ += Δg
    else                            gᵢ += Δg
    end

# Poisson inputs firing rates λ
fr_distr = LogNormal(median = 4Hz, g = 2)
λ = rand(fr_distr, N)
spiketimes = poisson_spikes.(λ, T)
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
