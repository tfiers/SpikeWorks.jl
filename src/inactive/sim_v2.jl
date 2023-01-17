
#=
Caveat for this file: imagine it's encapsulated in a `module SingleNeuron`.
or equivalently, types are prefixed, like `SingleNeuronModel`, `SingleNeuronRecording`.

I'll encapsulate and extract what's reusable later, when testing net sim.
(What'll be: most of init & step. Counter. The ontology).
=#

struct NeuronState{V<:AbstractVector}
    vars    ::V  # Current values of simulated variables
    Dₜvars  ::V  # Time derivatives of `vars` (Euler notation) [type it as D\_t<tab>]
                 # Aka dx/dt (Leibniz), x′ [\prime] (Lagrange), ẋ [\dot] (Newton)
end
NeuronState(vars_t₀) = begin
    x₀ = ComponentVector(vars_t₀)
    Dₜx₀ = zero(x₀) / second
    NeuronState(x₀, Dₜx₀)
end
NeuronState(m::NeuronModel) = NeuronState(m.vars_t₀)
@humanshow(NeuronState)

struct SimState{V}
    t       ::RefValue{Float64}
    neuron  ::NeuronState{V}
end
SimState(t₀::Float64, m::NeuronModel) = SimState(Ref(t₀), NeuronState(m))

@humanshow(SimState)
time(s::SimState) = s.t[]
show_datasummary(io::IO, s::SimState) = print(io,
    "t = ", fmt_time(s) * ", neuron = ", default_datasummary(s.neuron)
)
fmt_time(x) = fmt_time(time(x))
fmt_time(t::Float64) = @sprintf "%.3g seconds" t


struct Recording
    v          ::Vector{Float64}  # Voltage signal (hardcoded var atm)
    spiketimes ::Vector{Float64}
end
# Initialize buffers for recording a simulation of N timesteps long
Recording(N::Int) = begin
    v = Vector{Float64}(undef, N)  # Allocate full-length
    spiketimes = Float64[]         # Allocate empty
    Recording(v, spiketimes)
end
nspikes(r::Recording) = length(r.spiketimes)
@humanshow(Recording)

# "a simulation" = a 'run', a stretch in time
struct Simulation{S<:Nto1System, V}
    system       ::S
    Δt           ::Float64
    duration     ::Float64
    stepcounter  ::Counter
    state        ::SimState{V}
    rec          ::Recording
end
time(s::Simulation) = s.state.t[]
hasstarted(s::Simulation) = hasstarted(s.stepcounter)
completed(s::Simulation) = completed(s.stepcounter)
nspikes(s::Simulation) = nspikes(s.rec)
spikerate(s::Simulation) = nspikes(s) / time(s)
datasummary(s::Simulation) = begin
    hasstarted(s) || return "not started"
    time = fmt_time(s)
    fr = @sprintf("%.2g spikes/s", spikerate(s))
    (completed(s) ? "completed. $fr"
                  : "t = $time, $fr")
end
@humanshow(Simulation)

function Simulation(
    system    ::Nto1System,
    Δt        ::Float64;
    t₀        ::Float64 = zero(Δt),  # {We don't actually support nonzero t₀ atm: eg spikerate is wrong.}
    duration  ::Float64 = duration(system.input),
)
    nsteps = to_timesteps(duration, Δt)
    Simulation(
        system,
        Δt,
        duration,
        Counter(nsteps),
        SimState(t₀, system.neuronmodel),
        Recording(nsteps),
    )
end
unpack(s::Simulation) = (;
    s.stepcounter,
    s.system,
    s.state,
    s.Δt,
    s.rec,
    s.state.neuron.vars,
    s.state.neuron.Dₜvars,
    s.system.neuronmodel,
    s.system.input,
    s.system.on_spike_arrival!,
)
# For interactive use:
# Base.getproperty(s::Simulation, name::Symbol) = (
#     name in fieldnames(Simulation) ? getfield(s, name)
#                                    : unpack(s)[name]
# )
function step!(sim::Simulation{<:Nto1System})
    # Unpack names, for readability
    (; stepcounter, state, system, input,
       neuronmodel, vars, Dₜvars, Δt, rec
    ) = unpack(sim)
    # Step
    i = increment!(stepcounter)
    t = (state.t[] += Δt)
    # Handle incoming spikes
    arrivals = get_new_spikes!(input, t)
    for spike in arrivals
        system.on_spike_arrival!(vars, spike)
    end
    # Calculate differentials
    neuronmodel.f!(Dₜvars, vars)
    # Euler integration
    vars .+= Dₜvars * Δt
    if neuronmodel.has_spiked(vars)
        # Record self-spikes
        push!(rec.spiketimes, t)
        # Apply spike discontinuity
        neuronmodel.on_self_spike!(vars)
    end
    # Record membrane voltage
    rec.v[i] = vars.v
    return sim
end
function run!(s::Simulation)
    while !completed(s)
        step!(s)
    end
    return s
end
# simulate(system, Δt; kw...) = run!(Simulation(system, Δt; kw...))

newsim(neuron, inputs, on_spike_arrival!, Δt) =
    Simulation(Nto1System(neuron, inputs, on_spike_arrival!), Δt)

simulate(args...) = run!(newsim(args...))



# ~ docdump ~

# I know what onto should be:
# - `Simulation` -> SimState
# - `SimState`   -> SystemState
# - and at the end of the sim, create a SimResult (w/ a nice v-Signal eg :))

# I wanna get rid of ComponentArrays: too long types
# One option: https://github.com/MasonProtter/MutableNamedTuples.jl
#   It says "You should probably use StructArrays.jl though"
#     But no, cause I don't want user to have to make struct.
#   Although hm, still long type.
#   Can implement myself mayb ya.

# design is currently bad: Nto1System should be immutable.
# i.e. use PoissonSpikeSource instead of concrete trains
# (it's fine for now).
#
# inputs = [
#     SpikeSource(ID, PoissonSpiker(λ))
#     for (ID, λ) in zip(input_IDs, firing_rates)
# ]
# ..or sth


# [can use `(; u, v) = vars` syntax for diff order; no @unpack needed]

# Base.isless(x::Spike, y::Spike) = time(x) < time(y)
#
# `isequal` → `==` → `===`. The latter is automatically defined for immutable structs as:
# do they have the same contents (at bit level).
# This is indeed what we'd say: two spikes are equal if same source, and same time.


# Ideas to make better [but not necessary now]:
# - `vars, Dₜvars = neuron_state`
#    i.e. define iterator interface on NeuronState. (See how Pair does it).
#    (It's also cool, "first" and "second" derivative (no, it's 0th and 1st, but w/e))
# - Allow funcs(vars,Dₜvars) for spike_cond and on_self_spike! (and time as well ig :))
#   (yeah, just a wrapper in NeuronModel, used for all three F,G,H).
# - To check: does nonzero t₀ actually work (interaction with spiketrains eg)
#
# - There's sth not quite right with NeuronModel.vars_t₀. Cause you can have model eqs,
#   sim a bit, and then start running again, with diff "starting" values.
#
# - "SimState" is ehh. Cause I'd think that would just be time + vars (neuronstate).
#   Instead it has refs to recording, and steps..
#   It's sth like "SimRunInfo".
#   `completed(simrun)` makes more sense too. (:)
#     #[[magic of programming: if langauge doesnt' sit right,
#     then software design isn't either]])
#   Ok yes, that'd be better. but notnow.
#   ah, time might go with NeuronState yeh



# - "Here we've used the Julia convention that function that mutate their arguments end in
#    an exclamation mark".


# struct Time{T}
#     t::T
# end
# Base.convert(::Type{Time, t}) = Time(float(t))
#
# Cool, not now (we'd have to implement many ::Float methods)



# You can type the `₀` as \_0<tab>



# NeuronState{V}(x::V, ẋ::V) where V <: AbstractVector = begin
#     @assert length(x) == length(ẋ)
#     new(x, ẋ)
# end
# ↓
# so verbose, just to check if equal lengths


# [on field `system` of Simulation]:
# Ok, could be called `model` too. Eh, though: `.inputs`, not really.
# otoh, in step! it's quite cool:
#   model.neuron.f!()
#   model.on_spike_arrival!()
#
# maybe something: ?
#   (model, inputs) = system
#
# fucking hell yes that's cool
#
# it's kinda, boundary conditions
# vars_t₀ is also a bit hm, in neuronmodel; would it be better in inputs?
# or is it three things:
#   (model, inputs, x₀) = system
# Yes that sounds good.

# rename humanrepr to humanshow. add IO arg

# I'm thinking:
# - Every type has "oneline" summary
# - And those are used recursively for properties
# You can then zoom in on properties
# (and display multilevel if you want; colours and types, …)


# Idea: recursive unpack
# A function that makes a namedtuple (so, typed :)) of names of object, and within.
#   hm, but then you get internals of dict etc.
#   so maybe I'll just make it bespoke, for sim, with all its leaves
#
# Implementat: merge!(pairs_sth.(sim, sim.rec)...)
