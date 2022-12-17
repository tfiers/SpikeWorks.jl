
#=
Caveat for this file: imagine it's encapsulated in a `module SingleNeuron`.
or equivalently, types are prefixed, like `SingleNeuronModel`, `SingleNeuronRecording`.

I'll encapsulate and extract what's reusable later, when testing net sim.
(What'll be: most of init & step. Counter. The type division).
=#

function humanrepr(x::T) where T
    if hasmethod(show, Tuple{IO, MIME"text/plain", T})
        # For existing types, that did this the 'proper', verbose way.
        return repr(MIME("text/plain"), x)
        # hm. maybe not.¹ otoh, if we don't do it, and people wanna re-use
        # existing nice reprs from other packages, they need to type pirate
        # (the type from OtherPkg, `humanrepr` from this pkg)
        # So an alternative would be sth like
        #    `HumanRepr.use_plaintext_show(OtherPkg.Type)`
        # (which pushes to a global in HumanRepr pkg).
        #
        # ¹ why not? cause other types might eg print their typename already in the `[…]`,
        #   so that's duplicated.
    else
        # If no `show(, ::MIME"text/plain"…)` is defined, Julia falls back to plain `show`,
        # which we don't want.
        error("$humanrepr is not defined for $T")
    end
end

macro humanshow(T, f = humanrepr)
    esc(:(
        Base.show(io::IO, ::MIME"text/plain", x::$T) =
            print(io, nameof($T), " [", $f(x), "]")
    ))
    # `nameof(T)`, to not have module name
end


struct Counter
    N::Int
    i::RefValue{Int}

    function Counter(N, i)
        @test 0 ≤ i ≤ N
        new(N, Ref(convert(Int, i)))
    end
end
Counter(N) = Counter(N, 0)

current(c::Counter) = c.i[]
ntotal(c::Counter) = c.N

increment!(c::Counter) = (c.i[] += 1)
hasstarted(c::Counter) = (c.i[] > 0)
completed(c::Counter) = (c.i[] == c.N)
progress(c::Counter) = c.i[] / c.N

@humanshow(Counter)
humanrepr(c::Counter) = (completed(c) ? countstr(c.N)
                                      : countstr(c.i[], c.N))
countstr(N) = "$N (complete)"
countstr(i, N) = "$i/$N"

pctfmt(frac) = @sprintf("%.0f%%", 100*frac)



struct SpikeTrain
    spiketimes::Vector{Float64}
    duration::Float64

    SpikeTrain(s, d; copy = false, checksorted = true) = begin
        copy && (s = deepcopy(s))
        checksorted && issorted(s) || sort!(s)
        @test first(s) ≥ 0
        @test last(s) ≤ d
        new(s, d)
    end
end
spiketimes(t::SpikeTrain) = t.spiketimes
duration(t::SpikeTrain) = t.duration

nspikes(t::SpikeTrain) = length(spiketimes(t))
spikerate(t::SpikeTrain) = nspikes(t) / duration(t)


struct Nto1Input
    ID::Int
    train::SpikeTrain
end
spiketimes(x::Nto1Input) = spiketimes(x.train)


struct Spike
    time::Float64
    source::Int
end
time(s::Spike) = s.time
source(s::Spike) = s.source

Base.isless(x::Spike, y::Spike) = time(x) < time(y)

spikevec(input::Nto1Input) = [
    Spike(t, input.ID) for t in spiketimes(input)
]

struct SpikeFeed
    spikes::Vector{Spike}
    duration::Float64
    counter::Counter
    SpikeFeed(s, d) = new(s, d, Counter(length(s)))
end
duration(f::SpikeFeed) = f.duration
function SpikeFeed(inputs::AbstractVector{Nto1Input})
    spikevecs = [spikevec(i) for i in inputs]
    # Merge spikes
    spikes = reduce(vcat, spikevecs)
    sort!(spikes)
    max_duration = maximum([i.train.duration for i in inputs])
    return SpikeFeed(spikes, max_duration)
end
index_of_next(f::SpikeFeed) = current(f.counter)
next_spike(f::SpikeFeed) = @inbounds f.spikes[index_of_next(f)]
function get_new_spikes!(f::SpikeFeed, t)
    new_spikes = Spike[]
    while time(next_spike(f)) ≤ t
        push!(new_spikes, next_spike(f))
        increment!(f.counter)
    end
    return new_spikes
end

struct NeuronModel{V<:NamedTuple, F, G, H}
    vars_t₀         ::V
    f!              ::F
    has_spiked      ::G
    on_self_spike!  ::H
end
NeuronModel(    x₀, f!; has_spiked, on_self_spike!) =
    NeuronModel(x₀, f!, has_spiked, on_self_spike!)

abstract type Simulatable end

struct Nto1System{N<:NeuronModel, F} <: Simulatable
    neuronmodel       ::N
    input             ::SpikeFeed
    on_spike_arrival! ::F
end
Nto1System(m::NeuronModel, inputs::AbstractVector{Nto1Input}, f!) =
    Nto1System(m, SpikeFeed(inputs), f!)

humanrepr(s::Nto1System) = proplist(s)
@humanshow(Nto1System, proplist)

keyval_str(io, name, val) = begin

end
show_proplist(io, x) = begin
    for name in propertynames(x)
        val = getproperty(x, name)
        print(io, "\n  ", name, ": ")
        print(io, applicable(humanrepr, val) ? humanrepr(val) : val)
    end
end
proplist(x) = sprint(show_proplist, x; context = (:compact => true))


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
#
# 🦜🏴‍☠️
const CVec{Ax} = ComponentVector{Float64, Vector{Float64}, Ax}
Base.show(io::IO, ::Type{CVec{Ax}}) where Ax = print(io, "CVec{", varnames(Ax) ,"}")
varnames(::Type{Tuple{Axis{nt}}}) where nt = keys(nt)
#
humanrepr(n::NeuronState) = proplist(n)
@humanshow(NeuronState)


struct SimState{V}
    t       ::RefValue{Float64}
    neuron  ::NeuronState{V}
end
SimState(t₀::Float64, m::NeuronModel) = SimState(Ref(t₀), NeuronState(m))

time(s::SimState) = s.t[]
humanrepr(s::SimState) = "t: " * fmt_time(s) * ", " * humanrepr(s.neuron)
@humanshow(SimState)

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

# "a simulation" = a 'run', a stretch in time
struct Simulation{S<:Nto1System, V}
    system       ::S
    timestep     ::Float64
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
progress_str(s::Simulation) = begin
    hasstarted(s) || return "not started"
    time = fmt_time(s)
    pct = pctfmt(progress(s.stepcounter))
    rate = @sprintf("%.2g", spikerate(s))
    return "$time ($pct), $rate spikes/s"
end
@humanshow(Simulation, progress_str)

Simulation(
    system    ::Nto1System,
    Δt        ::Float64;
    t₀        ::Float64 = zero(Δt),  # {We don't actually support nonzero t₀ atm: eg spikerate is wrong.}
    duration  ::Float64 = duration(system.input),
)
    nsteps = to_timesteps(duration, Δt)
    return Simulation(
        system,
        Δt,
        duration,
        Counter(nsteps),
        SimState(t₀, system.neuronmodel),
        Recording(nsteps),
    )
end
function step!(sim::Simulation{<:Nto1System})
    i = increment!(sim.stepcounter)
    (; state, system, Δt, rec) = sim      # Unpack some names for readability
    (; vars, Dₜvars) = state.neuron;
    (; neuronmodel) = system
    neuronmodel.f!(vars, Dₜvars)          # Calculate differentials
    Δt = sim.timestep
    vars .+= Dₜvars * Δt                  # Euler integration
    t = (state.t[] += Δt)
    rec.v[i] = vars.v                     # Record membrane voltage..
    if neuronmodel.has_spiked(vars)
        push!(rec.spiketimes, t)          # ..and self-spikes
        neuronmodel.on_self_spike!(vars)  # Apply spike discontinuity
    end
    arrivals = get_new_spikes!(system.input, t)
    for spike in arrivals
        system.on_spike_arrival!(vars, spike)
    end
    return sim
end
function run!(s::Simulation)
    while !completed(s)
        step!(s)
    end
    return s
end
simulate(system, Δt; kw...) = run!(Simulation(system, Δt; kw...))





# ~ docdump ~

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
# - Spike struct, with isless. So no sortperm needed to mux.
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
# Base.convert(::Type{Time, t) = Time(float(t))
#
# Cool, not now (we'd have to implement many ::Float methods)



# You can type the `₀` as \_0<tab>



# NeuronState{V}(x::V, ẋ::V) where V <: AbstractVector = begin
#     @test length(x) == length(ẋ)
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
