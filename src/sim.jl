
@kwdef struct NeuronModel_{V,F,G,H}
    x₀                 ::V            # You can type the `₀` as \_0<tab>
    diffeqs            ::F
    spiking_condition  ::G
    on_self_spike      ::H
end
NeuronModel = NeuronModel_

# If you don't want to type `x₀` (with its subscript):
#   provide it (i.e. 'the simvars and their initial values') as unnamed first argument
NeuronModel_(x₀; kw...) = NeuronModel(; x₀, kw...)



# Multiplexed spiketrains
# (i.e. multiple spiketrains merged into one 'channel')
struct SpikeMux_
    train      ::SpikeTrain
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



struct Nto1Model_{N<:NeuronModel, F}
    neuron            ::N
    input             ::SpikeMux
    on_spike_arrival  ::F  # f(spike_source_ID, neuron.vars)
end
Nto1Model = Nto1Model_


pack(; vars...) = CVector(; vars...)
derivatives(vars) = zero(vars/second)
# vars = pack(x₀)
# (vars, derivatives(vars))
