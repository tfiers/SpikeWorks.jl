using Firework
using Firework.Units
using Firework: LogNormal

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
coba_izh_neuron = NeuronModel(
    # Simulated variables and their initial values
    (
        # Izhikevich variables
        v   = vᵣ,      # Membrane potential
        u   = 0 * pA,  # Adaptation current
        # Synaptic conductances g
        gₑ  = 0 * nS,  # = Sum over all exc. synapses
        gᵢ  = 0 * nS,  # = Sum over all inh. synapses
    ),
    # Differential equations: calculate time derivatives of simulated vars
    # (and store them "in-place", in `Dₜ`).
    (Dₜ, vars) -> begin
        v, u, gₑ, gᵢ = vars

        # Conductance-based synaptic current
        Iₛ = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

        # Izhikevich 2D system
        Dₜ.v = (k*(v-vₗ)*(v-vₜ) - u - Iₛ) / C
        Dₜ.u = a*(b*(v-vₗ) - u)

        # Synaptic conductance decay
        Dₜ.gₑ = -gₑ / τ
        Dₜ.gᵢ = -gᵢ / τ
    end;
    has_spiked = (vars) -> (vars.v ≥ vₛ),
    on_self_spike! = (vars) -> begin
        vars.v = vᵣ
        vars.u += Δu
    end
)


# Inputs

# Params
@typed begin
    Nₑ = 40
    Nᵢ = 10
    Δgₑ = 60nS / Nₑ
    Δgᵢ = 60nS / Nᵢ
end

N = Nₑ + Nᵢ
input_IDs = 1:N
@enum NeuronType exc inh
neuron_type(ID) = (ID ≤ Nₑ) ? exc : inh

on_spike_arrival!(vars, spike) =
    if neuron_type(source(spike)) == exc
        vars.gₑ += Δgₑ
    else
        vars.gᵢ += Δgᵢ
    end

# Firing rates λ for the Poisson inputs
fr_distr = LogNormal(median = 4Hz, g = 2)
firing_rates = rand(fr_distr, N)

sim_duration = 10seconds

inputs = [
    Nto1Input(ID, poisson_SpikeTrain(λ, sim_duration))
    for (ID, λ) in zip(input_IDs, firing_rates)
]

system = Nto1System(coba_izh_neuron, inputs, on_spike_arrival!)

Δt = 0.1ms      # Sim timestep

# sim = simulate(system, Δt)

using Firework: Simulation, step!, run!, unpack, newsim,
                get_new_spikes!

# sim = Simulation(system, Δt)
# s = unpack(sim); nothing
#step!(sim)

new() = newsim(coba_izh_neuron, inputs, on_spike_arrival!, Δt)

s0 = new()

s = run!(new())
