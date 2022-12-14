
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
