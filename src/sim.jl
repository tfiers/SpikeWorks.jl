
#=
Caveat for this file: imagine it's encapsulated in a `module SingleNeuron`.
or equivalently, types are prefixed, like `SingleNeuronModel`, `SingleNeuronRecording`.

I'll encapsulate and extract what's reusable later, when testing net sim.
(What'll be: most of init & step. Counter. The type division).
=#

function humanrepr(x::T) where T
    if hasmethod(show, Tuple{IO, MIME"text/plain", T})
        # For existing types, that did this the 'proper', verbose way.
        return repr(MIME"text/plain", x)
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
            print(io, "$T [", $f(x), "]")
    ))
end



struct Counter
    i::RefValue{Int}
    N::Int

    Counter(i, N) = begin
        i = convert(Int, i)
        @test 1 ≤ i ≤ N
        new(Ref(i), N)
    end
end
Counter(N) = Counter(1, N)

current(c::Counter) = c.i[]
ntotal(c::Counter) = c.N

increment!(c::Counter) = (c.i[] += 1)  # or: step!
completed(c::Counter) = (c.i[] == c.N)

humanrepr(c::Counter) = (completed(c) ? countstr(c.N)
                                      : countstr(c.i[], c.N))
countstr(N) = "$N (complete)"
countstr(i, N) = "$i/$N"

@humanshow(Counter)



struct NeuronModel_{V,F,G,H}
    vars_t₀         ::V   # You can type the `₀` as \_0<tab>
    Dₜvars!         ::F
    has_spiked      ::G
    on_self_spike!  ::H
end
NeuronModel = NeuronModel_

NeuronModel_(x₀, f!; has_spiked, on_self_spike!) =
NeuronModel_(x₀, f!, has_spiked, on_self_spike!)

# - "Here we've used the Julia convention that function that mutate their arguments end in
#    an exclamation mark".



# struct Time{T}
#     t::T
# end
# Base.convert(::Type{Time, t) = Time(float(t))
#
# Cool, not now (we'd have to implement many ::Float methods)



struct Spike{T}  #{T<:Time}
    time::T
    source::Int
end

time(s::Spike) = s.time
source(s::Spike) = s.source

time(t::Float64) = t
# ↪ To allow plain floats for train.spikes. Temp, see Time ↖

Base.isless(x::Spike, y::Spike) = x.time < y.time
#
# `isequal` → `==` → `===`. The latter is automatically defined for immutable structs as:
# do they have the same contents (at bit level).
# This is indeed what we'd say: two spikes are equal if same source, and same time.



struct SpikeTrain{T}
    spikes::Vector{Spike{T}}
    duration::T

    SpikeTrain(s, d; copy = false, already_sorted = false) = begin
        copy && (s = deepcopy(s))
        already_sorted || sort!(s)
        @test time(first(s)) ≥ 0
        @test time(last(s)) ≤ d
        new(s, d)
    end
end

SpikeTrain(spiketimes::AbstractVector{T}, duration::T, ID; kw...) where T =
    SpikeTrain(Spike.(spiketimes, ID), duration, kw...)

# more proper would be:
# - rename current `SpikeTrain` to `SpikeMux`.
# - a new type SpikeTrain.
# Prob both can inherit from some kind of EventSequence / Train

# # Array interface
# Base.IndexStyle(::SpikeTrain) = IndexLinear
# Base.getindex(t::SpikeTrain, i::Int) = t.spikes[i]
# Base.size(t::SpikeTrain) = size(t.spikes)
# Base.eltype(::SpikeTrain{T}) where T = Spike{T}

spikes(t::SpikeTrain) = t.spikes
duration(t::SpikeTrain) = t.duration

spiketimes(t::SpikeTrain) = [time(s) for s in spikes(t)]
nspikes(t::SpikeTrain) = length(spikes(t))
spikerate(t::SpikeTrain) = nspikes(t) / duration(t)

Base.merge(t::SpikeTrain, others...) = merge_all((t, others...))
function merge_all(trains::AbstractVector{<:SpikeTrain})
    all_spikes = reduce(vcat, (spikes(t) for t in trains))
    max_duration = maximum(duration, trains)
    return SpikeTrain(all_spikes, max_duration)
end
# Base.convert(::Type{SpikeTrain}, x::AbstractVector{<:SpikeTrain}) = merge_all(x)
# # ↪ Used by Nto1Model's default constructor (untyped args) when passed multiple trains



struct SpikeFeed{T<:SpikeTrain}
    train::SpikeTrain{T}
    counter::Counter

    SpikeFeed(t::SpikeTrain) = begin
        N = length(t)
        new(t, Counter(N))
    end
end

spikes(f::SpikeFeed) = spikes(f.train)
index_of_next(f::SpikeFeed) = current(f.counter)
next_spike(f::SpikeFeed) = @inbounds spikes(f)[index_of_next(f)]

function get_new_spikes!(f::SpikeFeed{T}, t::T) where T
    new_spikes = Spike{T}[]
    while time(next_spike(f)) ≤ t
        push!(new_spikes, next_spike(f))
        increment!(f.counter)
    end
    return new_spikes
end

# (We could have generalizations: Train{Event}, Feed{Event}).
# (Then:
#   alias `SpikeTrain{T} where T = Train{Spike{T}}`
#  (like Vector→Array, or CVec→CArr))


struct Nto1Model_{N<:NeuronModel,S<:SpikeFeed,F}
    neuron            ::N
    input             ::S
    on_spike_arrival! ::F  # f(neuron_state.vars, spike_source_ID)
end
Nto1Model = Nto1Model_

Nto1Model_()



struct NeuronState{V<:AbstractVector}
    vars    ::V  # Current values of simulated variables
    Dₜvars  ::V  # Time derivatives of `vars` (Euler notation) [type it as D\_t<tab>]
                 # Aka dx/dt (Leibniz), x′ (Lagrange) [\prime], ẋ (Newton) [\dot]
    NeuronState(vars, Dₜvars = zero(vars/second)) = begin
        @test length(vars) == length(Dₜvars)
        new(vars, Dₜvars)
    end
end
NeuronState(; vars...) = NeuronState(ComponentVector(; vars...))



struct Recording{T}
    v          ::Vector{T}
    spiketimes ::Vector{T}
end
# Initialize buffers for a recording of N timesteps long.
Recording(N) = begin
    v = Vector{T}(undef, N)  # Allocate full-length array
    spiketimes = T[]         # Allocate empty array
    return Recording(v, spiketimes)
end
nspikes(r::Recording) = length(r.spiketimes)

progress_str(r::Recording) = (N = nspikes(r); "$N spikes")
@humanshow(Recording, progress_str)



struct SimState{T,V<:AbstractVector{T}}
    t       ::RefValue{T}
    step    ::Counter
    neuron  ::NeuronState{V}
    rec     ::Recording{T}
end

progress_str(s::SimState) = humanrepr(s.step) * ", " * progress_str(s.rec)
@humanshow(SimState, progress_str)

completed(s::SimState) = completed(s.step)

function init_sim(
    model    ::Nto1Model,
    Δt       ::T;
    t₀       ::T = zero(Δt),
    duration ::T = model.input.duration,
) where T
    N = to_timesteps(duration, Δt)
    step = Counter(N)
    neuron_init = NeuronState(; model.neuron.vars_t₀...)
    rec = Recording(N)
    return SimState(Ref(t₀), step, neuron_init, rec)
end

function step!(state::SimState, model::Nto1Model, Δt)
    i = increment!(state.step)
    (; vars, Dₜvars) = state.neuron        # Unpack, for readability
    model.neuron.f!(vars, Dₜvars)          # Calculate differentials
    vars .+= Dₜvars * Δt                   # Euler integration
    t = (state.t[] += Δt)
    state.rec.v[i] = vars.v                # Record membrane voltage..
    if model.neuron.has_spiked(vars)
        push!(rec.spiketimes, t)           # ..and self-spikes.
        model.neuron.on_self_spike!(vars)  # Apply spike discontinuity
    end
    arrivals = get_new_spikes!(model.input, t)
    for spike in arrivals
        model.on_spike_arrival!(vars, spike)
    end
    return state
end
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

function sim(model::Nto1Model, Δt::T; initkw...)
    state = init_sim(m, Δt; initkw...)
    while !completed(state)
        step!(state, m)
    end
    return state.rec
end
