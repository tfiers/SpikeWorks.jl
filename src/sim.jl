
#=
Caveat for this file: imagine it's encapsulated in a `module SingleNeuron`.
or equivalently, types are prefixed, like `SingleNeuronModel`, `SingleNeuronRecording`.

I'll encapsulate and extract what's reusable later, when testing net sim.
(What'll be: most of init & step. StepCount. The type division).
=#


@kwdef struct NeuronModel_{V,F,G,H}
    x₀              ::V   # You can type the `₀` as \_0<tab>
    f!              ::F
    has_spiked      ::G
    on_self_spike!  ::H
end
NeuronModel = NeuronModel_

# If you don't want to type `x₀` (with its subscript):
#   provide it (i.e. 'the simvars and their initial values') as unnamed first argument
NeuronModel_(x₀; kw...) = NeuronModel(; x₀, kw...)
# You may also provide the 'eval diffeqs' function by position
NeuronModel_(x₀, f!; kw...) = NeuronModel(; x₀, f!, kw...)



# Multiplexed spiketrains
# (i.e. multiple spiketrains merged into one 'channel')
struct SpikeMux_{T}
    train      ::SpikeTrain{T}
    sourceIDs  ::Vector{Int}

    SpikeMux_(t, s) = begin
        @assert length(s) == length(t)
        new(t, s)
    end
end
SpikeMux = SpikeMux_

# Merge spiketimes,
# and make parallel array, with source IDs of each spike.
function multiplex(
    trains ::AbstractVector{SpikeTrain},
    IDs    ::AbstractVector{Int} = 1:length(trains)
)
    @assert length(IDs) == length(trains)

    spiketime_vecs = [spiketimes(t) for t in trains]

    spikesource_vecs = [fill(ID, numspikes(t)) for (t, ID) in zip(trains, IDs)]

    times_concat   = reduce(vcat, spiketime_vecs)
    sources_concat = reduce(vcat, spikesource_vecs)
    # Sort the spiketimes
    order = sortperm(time)
    # Apply this order to both vectors.
    # I.e., sort the spike-source IDs according to the spike-times
    merged_times   = times_concat[order]
    merged_sources = sources_concat[order]
    # (`x[order]` is "generally faster" than `permute!(x, order)`;
    #  but twice the memory usage (GC tho)).

    max_duration = maximum(duration, trains)
    merged_train = SpikeTrain(merged_times, max_duration, checksorted = false)
    return SpikeMux(merged_train, merged_sources)
end

Base.convert(::Type{SpikeMux}, x::AbstractVector{SpikeTrain}) = multiplex(x)
# ↪ Used by Nto1Model's default `::Any` constructor


struct Nto1Model_{N<:NeuronModel,T,F}
    neuron            ::N
    input             ::SpikeMux{T}
    on_spike_arrival! ::F           # f(neuron_state.vars, spike_source_ID)
end
Nto1Model = Nto1Model_




struct StepCount
    i     ::RefValue{Int}
    N     ::Int

    StepCount(i::Int, N) = begin
        @assert 1 ≤ i ≤ N
        new(Ref(i), N)
    end
end
StepCount(N) = StepCount(1, N)

increment!(s::StepCount) = (s.i[] += 1)
progress_str(s::StepCount) = "step " * stepstr(s.i[], s.N)
stepstr(i, N) = if     (i < N)   "$i/$N"
                elseif (i == N)  "$i (complete)"
                end



function humanrepr end
#
# julia> @humanrepr(MyType, (x) -> "something $(x.prop)")`
# julia> x = MyType("sweet");
# julia> x
# MyType [something sweet]
#
# (The newly defined `humanrepr` method for MyType may now be used when pretty-printing
#  other types, too).
macro humanrepr(T, f)
    ex = quote
        # Avoid recursive definition of `humanrepr(::T)`
        if !hasmethod(humanrepr, $T)
            humanrepr(x::$T) = $f(x)
        end
        Base.show(io::IO, ::MIME"text/plain", x::$T) =
        print(io, $T, " ", "[", humanrepr(x), "]")
    )
    esc(ex)
end


@humanrepr(StepCount, progress_str)


struct NeuronState{V<:AbstractVector}
    x ::V  # Current values of simulated variables
    ẋ ::V  # Time derivatives of `x` (Newton notation)
           # Aka dx/dt (Leibniz), Dₜx (Euler), x′ (Lagrange).
           # You can type it as `x\dot<tab>`  (AHK: \.)
    NeuronState(x, ẋ = zero(x/second)) = begin
        @assert length(x) == length(ẋ)
        new(x, ẋ)
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

progress_str(r::Recording) = "$(nspikes(r)) spikes"
@humanrepr(Recording, progress_str)



struct SimState{T,V<:AbstractVector{T}}
    t      ::RefValue{T}
    step   ::StepCount
    neuron ::NeuronState{V}
    rec    ::Recording{T}
end

progress_str(s::SimState) = progress_str(s.step) * ", " * progress_str(s.rec)
@humanrepr(SimState, progress_str)

function init_sim(
    model    ::Nto1Model,
    Δt       ::T;
    t₀       ::T = zero(Δt),
    duration ::T = model.input.duration,
) where T
    N = to_timesteps(duration, Δt)
    step = StepCount(N)
    neuron_init = NeuronState(; model.neuron.x₀...)
    rec = Recording(N)
    return SimState(Ref(t₀), step, neuron_init, rec)
end

function step!(state::SimState, model::Nto1Model, Δt)
    i = increment!(state.step)
    (; x, ẋ) = state.neuron             # Unpack, for readability
    model.neuron.f!(x, ẋ)               # Calculate differentials
    x .+= dx .* Δt                      # Euler integration
    t = (state.t[] += Δt)
    state.rec.v[i] = x.v                # Record membrane voltage..
    if model.neuron.has_spiked(x)
        push!(rec.spiketimes, t)        # ..and self-spikes.
        model.neuron.on_self_spike!(x)  # Apply spike discontinuity
    end
    arrivals = get_new_spikes!(model.input, t)
    for spike in arrivals
        model.on_spike_arrival!(x, spike.source)
    end
    return state
end
# Ideas to make better [but not necessary now]:
# - `x, ẋ = neuron_state`
#    i.e. define iterator interface on NeuronState.
#    (It's also cool, "first" and "second" derivative (no, it's 0th and 1st, but w/e))
# - Allow funcs(x,ẋ) for spike_cond and on_self_spike! (and time as well ig :))
#   (yeah, just a wrapper in NeuronModel, used for all three F,G,H).
# - To check: does nonzero t₀ actually work (interaction with spiketrains eg)

function sim(model::Nto1Model, Δt)
    state = init_sim(model, Δt)
end
