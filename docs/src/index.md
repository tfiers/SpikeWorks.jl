# Firework.jl

## Model specification
```
@eqs
show_eqs
```

```@docs
poisson_spikes
```

## Distributions
```@docs
Firework.LogNormal
```

## Discrete time
```@docs
to_timesteps
```

## SpikeFeed

```@docs
Firework.SpikeFeed
Firework.advance_to!
```

### Usage

Import explicitly (`SpikeFeed` is not exported
as it is not needed in standard end use).
```jldoctest sf
julia> using Firework: SpikeFeed, advance_to!
```
\

Construct feed. The provided spike times must already be sorted.
```jldoctest sf
julia> sf = SpikeFeed([1.0, 2.0, 4.0]);
```
\

When printed, the `[seen/total]` number of spikes are shown:
```jldoctest sf
julia> sf
SpikeFeed [0/3] (next: 1.0)
```
\

Advance the feed by providing the current time.
The number of newly seen spikes is returned.
```jldoctest sf
julia> advance_to!(sf, 3.0)
2

julia> advance_to!(sf, 3.0)
0

julia> sf
SpikeFeed [2/3] (next: 4.0)
```
\

We advance up to *and including* the given time.
```jldoctest sf
julia> advance_to!(sf, 4.0)
1

julia> sf
SpikeFeed [3/3] (exhausted)
```
