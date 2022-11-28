
"""
    SpikeTrain(spiketimes, duration; checksorted = true, makecopy = false)

Wrapper around a sorted list of spike times. Additionally, has a `duration` property. (The
spikes must occur within the time interval `[0, duration]`. So no negative spike times).
"""
struct SpikeTrain
    spiketimes::Vector{Float64}
    duration::Float64

    SpikeTrain(spiketimes, duration; checksorted = true, makecopy = false) = begin
        spiketimes = makecopy ? copy(spiketimes) : spiketimes
        if checksorted && !issorted(spiketimes)
            sort!(spiketimes)
        end
        @assert first(spiketimes) ≥ 0
        @assert last(spiketimes) ≤ duration
        new(spiketimes, duration)
    end
end
Base.IndexStyle(::SpikeTrain) = IndexLinear
Base.getindex(t::SpikeTrain, i::Int) = t.spiketimes[i]
Base.size(t::SpikeTrain) = size(t.spiketimes)

spiketimes(t::SpikeTrain) = t.spiketimes
duration(t::SpikeTrain) = t.duration

numspikes(t::SpikeTrain) = length(t)
spikerate(t::SpikeTrain) = numspikes(t) / duration(t)

Base.merge(trains::AbstractVector{SpikeTrain}) =
    SpikeTrain(
        merge_sorted(spiketimes.(trains)),
        maximum(duration, trains);
        checksorted = false,
    )

merge_sorted(vecs) = sort!(reduce(vcat, vecs))
# ↪ This implementation does not explicitly make use of the fact that the vecs are already
#   sorted. But quicksort performs well here. Much better than a specific implementation of
#   `merge_sorted` I wrote (see commit a0bc3c8 / this file and <test/merge_sorted.jl>).
#
#   Note that `reduce(vcat, vecs)` is efficient. It doesn't do the default reduce thing,
#   where it would iteratively allocate larger and larger arrays and repeatedly copy over
#   the same data. Rather, there is a `reduce` method specialized on `::typeof(vcat)` that
#   allocates the final big array in one go. (Specifically, see `_typed_vcat(::Type{T},
#    V::AbstractVecOrTuple{AbstractVector})` in `abstractarray.jl`).
#   (The use of `reduce` for non-reduce functionality is unintuitive, Julia Base designers).
