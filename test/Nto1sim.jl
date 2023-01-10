using SpikeWorks
using SpikeWorks.Units
using SpikeWorks: LogNormal

# Neuron-model parameters
@typed begin
    # Izhikevich params
    C  =  100    * pF        # Cell capacitance
    k  =    0.7  * (nS/mV)   # Steepness of parabola in v̇(v)
    vₗ = - 60    * mV        # Resting ('leak') membrane potential
    vₜ = - 40    * mV        # Spiking threshold (when no syn. & adaptation currents)
    a  =    0.03 / ms        # Reciprocal of time constant of adaptation current `u`
    b  = -  2    * nS        # (v-vₗ)→u coupling strength
    vₛ =   35    * mV        # Spike cutoff (defines spike time)
    vᵣ = - 50    * mV        # Reset voltage after spike
    Δu =  100    * pA        # Adaptation current inflow on self-spike
    # Conductance-based synapses
    Eₑ =   0 * mV            # Reversal potential at excitatory synapses
    Eᵢ = -80 * mV            # Reversal potential at inhibitory synapses
    τ  =   7 * ms            # Time constant for synaptic conductances' decay
end

# Conductance-based Izhikevich neuron
#
# Simulated variables and their initial values
@kwdef mutable struct CobaIzhNeuron
    # Izhikevich variables
    v   = vᵣ      # Membrane potential
    u   = 0 * pA  # Adaptation current
    # Synaptic conductances g
    gₑ  = 0 * nS  # = Sum over all exc. synapses
    gᵢ  = 0 * nS  # = Sum over all inh. synapses
end

# Conductance-based synaptic current
# Iₛ(n::CobaIzhNeuron) = let (; v, gₑ, gᵢ) = n
#   gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
#
# or:
synaptic_current(n::CobaIzhNeuron) =
    let (; v, gₑ, gᵢ) = n

        gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
    end

#
# Differential equations: calculate time derivatives of simulated vars
# (and store them "in-place", in `Dₜ`).
function update!(Dₜ, n::CobaIzhNeuron)
    (; v, u, gₑ, gᵢ) = n

    # Conductance-based synaptic current
    Iₛ = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    # Izhikevich 2D system
    Dₜ.v = (k*(v-vₗ)*(v-vₜ) - u - Iₛ) / C
    Dₜ.u = a*(b*(v-vₗ) - u)

    # Synaptic conductance decay
    Dₜ.gₑ = -gₑ / τ
    Dₜ.gᵢ = -gᵢ / τ
end

has_spiked(n::CobaIzhNeuron) = (n.v ≥ vₛ)

on_self_spike!(n::CobaIzhNeuron)

coba_izh_neuron = NeuronModel(
    has_spiked = (vars) -> (vars.v ≥ vₛ),
    on_self_spike! = (vars) -> begin
        vars.v = vᵣ
        vars.u += Δu
    end
)


# Inputs

# Params
@typed
    N = 100
    EIratio = 4//1
end

@enum NeuronType exc inh

function init_sim(N = N)
    Nₑ, Nᵢ = groupsizes(EIMix(N, EIratio))
    Δgₑ = 60nS / Nₑ
    Δgᵢ = 60nS / Nᵢ
    input_IDs = 1:N
    neuron_type(ID) = (ID ≤ Nₑ) ? exc : inh
    on_spike_arrival!(vars, spike) =
        if neuron_type(source(spike)) == exc
            vars.gₑ += Δgₑ
        else
            vars.gᵢ += Δgᵢ
        end
end

# Firing rates λ for the Poisson inputs
fr_distr = LogNormal(median = 4Hz, g = 2)
firing_rates = rand(fr_distr, N)

# sim_duration = 10seconds
sim_duration = 10minutes

inputs = [
    Nto1Input(ID, poisson_SpikeTrain(λ, sim_duration))
    for (ID, λ) in zip(input_IDs, firing_rates)
]

system = Nto1System(coba_izh_neuron, inputs, on_spike_arrival!)

Δt = 0.1ms      # Sim timestep

# sim = simulate(system, Δt)

using SpikeWorks: Simulation, step!, run!, unpack, newsim,
                get_new_spikes!, next_spike, index_of_next

# sim = Simulation(system, Δt)
# s = unpack(sim); nothing
#step!(sim)

new() = newsim(coba_izh_neuron, inputs, on_spike_arrival!, Δt)

# s0 = new()

# s = run!(new())
