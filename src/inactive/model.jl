
struct NeuronModel{V<:NamedTuple, F, G, H}
    vars_t₀         ::V
    f!              ::F
    has_spiked      ::G
    on_self_spike!  ::H
end
NeuronModel(x₀, f!; has_spiked, on_self_spike!) =
    NeuronModel(x₀, f!, has_spiked, on_self_spike!)



struct SpikeTrain
    spiketimes::Vector{Float64}
    duration::Float64

    SpikeTrain(s, d; copy = false, checksorted = true) = begin
        copy && (s = deepcopy(s))
        checksorted && issorted(s) || sort!(s)
        @assert first(s) ≥ 0
        @assert last(s) ≤ d
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

# (This should be a type, later)
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
@humanshow(SpikeFeed)
datasummary(f::SpikeFeed) = begin
    i, N = state(f.counter)
    (i == N ? "all $N spikes processed"
            : "$i/$N spikes processed")
end
# Multiplex different spiketrains into one 'stream'
function SpikeFeed(inputs::AbstractVector{Nto1Input})
    spikevecs = [spikevec(i) for i in inputs]
    # Merge spikes
    spikes = reduce(vcat, spikevecs)
    sort!(spikes)
    max_duration = maximum([i.train.duration for i in inputs])
    return SpikeFeed(spikes, max_duration)
end

function get_new_spikes!(f::SpikeFeed, t)
    new_spikes = Spike[]
    while !completed(f) && time(next_spike(f)) ≤ t
        push!(new_spikes, next_spike(f))
        increment!(f.counter)
    end
    return new_spikes
end
next_spike(f::SpikeFeed) = @inbounds f.spikes[index_of_next(f)]
index_of_next(f::SpikeFeed) = unsafe_current(f.counter) + 1
completed(f::SpikeFeed) = completed(f.counter)




struct Nto1System{N<:NeuronModel, F}
    neuronmodel       ::N
    input             ::SpikeFeed
    on_spike_arrival! ::F
end
Nto1System(m::NeuronModel, inputs::AbstractVector{Nto1Input}, f!) =
    Nto1System(m, SpikeFeed(inputs), f!)

@humanshow(Nto1System)
show_datasummary(io::IO, x::Nto1System) = print(io,
    Nto1System, ", ",
    "x₀: ", x.neuronmodel.vars_t₀, ", ",
    "input feed: ", datasummary(x.input),
)
