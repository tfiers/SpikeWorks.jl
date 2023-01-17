using SpikeWorks
using SpikeWorks.Units
using SpikeWorks: LogNormal

# Neuron-model parameters
@typed begin
    # Izhikevich params
    C  =  100    * pF    # Cell capacitance
    k  =    0.7  * nS/mV # Steepness of parabola in v̇(v)
    vₗ = - 60    * mV    # Resting (or 'leak') membrane potential
    vₜ = - 40    * mV    # Spiking threshold (when no synaptic & adaptation currents)
    a  =    0.03 / ms    # Reciprocal of time constant of adaptation current `u`
    b  = -  2    * nS    # (v-vₗ)→u coupling strength
    vₛ =   35    * mV    # Spike cutoff (defines spike time)
    vᵣ = - 50    * mV    # Reset voltage after spike
    Δu =  100    * pA    # Adaptation current inflow on self-spike
    # Conductance-based synapses
    Eₑ =   0 * mV        # Reversal potential at excitatory synapses
    Eᵢ = -80 * mV        # Reversal potential at inhibitory synapses
    τ  =   7 * ms        # Time constant for synaptic conductances' decay
end

# Conductance-based Izhikevich neuron
#
# Define type and the simulated variables, and set their initial values
@Neuron CobaIzhNeuron begin
    # Izhikevich variables
    v   = vᵣ      # Membrane potential
    u   = 0 * pA  # Adaptation current
    # Synaptic conductances g
    gₑ  = 0 * nS  # = Sum over all exc. synapses
    gᵢ  = 0 * nS  # = Sum over all inh. synapses
end
# To be able to extend another module's functions: need to qualify their names.
# (A silent failure if you don't..)
# (or alternatively do `import SpikeWorks: update_derivatives!, …` but that's repetitive)
import SpikeWorks as SW
# Differential equations: calculate time derivatives of simulated vars,
# and store them "in-place", in `Dₜ`
SW.update_derivatives!(n::CobaIzhNeuron) = let (; v, u, gₑ, gᵢ) = vars(n),
                                            Dₜ = derivatives(n)
    # Conductance-based synaptic current
    Iₛ = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    # Izhikevich 2D system
    Dₜ.v = (k*(v-vₗ)*(v-vₜ) - u - Iₛ) / C
    Dₜ.u = a*(b*(v-vₗ) - u)

    # Synaptic conductance decay
    Dₜ.gₑ = -gₑ / τ
    Dₜ.gᵢ = -gᵢ / τ
end
SW.has_spiked(n::CobaIzhNeuron) = (
    vars(n).v ≥ vₛ
)
SW.on_self_spike!(n::CobaIzhNeuron) = begin
    vars(n).v = vᵣ
    vars(n).u += Δu
end

# SW.vars_to_record(::CobaIzhNeuron) = [:v]

sim_duration = 10seconds
sim_duration = 10minutes

struct Nto1System <: System
    neuron::CobaIzhNeuron
    exc_inputs::SpikeMux
    inh_inputs::SpikeMux
    unconnected::
end

# Firing rates λ for the Poisson inputs
firing_rate_distr = LogNormal(median = 4Hz, g = 2)

@enum NeuronType exc inh

"Create a new Nto1System with `N` Poisson input neurons"
sys(
    N = 100,
    EIratio = 4//1,
) = begin
    # Draw new firing rates
    firing_rates = rand(firing_rate_distr, N)
    inputs = PoissonSpikeSource.(firing_rates)
    (; Nₑ) = EIMix(N, EIratio)
    exc_inputs = inputs[1:Nₑ]
    inh_inputs = inputs[Nₑ+1:end]
    Δgₑ = 60nS / Nₑ
    Δgᵢ = 60nS / Nᵢ
    neuron = CobaIzhNeuron()
    input = SpikeMux()
    Nto1System(; input)
end

inputs = []
sys = Nto1System(neuron)


input(;
) = begin
    input_IDs = 1:N
    inputs = [
        Nto1Input(ID, poisson_SpikeTrain(λ, sim_duration))
        for (ID, λ) in zip(input_IDs, firing_rates)
    ]
    neuron_type(ID) = (ID ≤ Nₑ) ? exc : inh

    on_spike_arrival!(vars, spike) =
        if neuron_type(source(spike)) == exc
            vars.gₑ += Δgₑ
        else
            vars.gᵢ += Δgᵢ
        end
    return (;
        firing_rates,
        inputs,
        on_spike_arrival!,
        Nₑ,
    )
end
Δt = 0.1ms      # Sim timestep

ip = input(N=6400);

using SpikeWorks: Simulation, step!, run!, unpack, newsim,
                  get_new_spikes!, next_spike, index_of_next

# system = Nto1System(coba_izh_neuron, ip.inputs, ip.on_spike_arrival!)
new() = newsim(coba_izh_neuron, ip.inputs, ip.on_spike_arrival!, Δt)

# s0 = new()
# s = run!(new())
