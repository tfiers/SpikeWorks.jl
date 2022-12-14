
struct NeuronModel_{V,D,F,G,H}
    vars          ::V
    derivs        ::D
    diffeqs       ::F
    has_spiked    ::G
    on_self_spike ::H
end
NeuronModel = NeuronModel_

NeuronModel_(x₀, f, g, h) = begin
    vars = pack(x₀)
    return NeuronModel(vars, derivatives(vars), f, g, h)
end
pack(; vars...) = CVector(; vars...)
derivatives(vars) = zero(vars/second)



# Multiplexed spiketrains
struct SpikeMux_
    spikes::SpikeTrain
    sourceIDs::Vector{Int}
    # add: lengths== assert
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



struct Nto1Model_{N<:NeuronModel, F}
    input             ::SpikeMux
    neuron            ::N
    on_spike_arrival  ::F  # f(spike_source_ID, neuron.vars)
end
Nto1Model = Nto1Model_
