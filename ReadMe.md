# SpikeLab

⋮

We use unicode variable names, like `τₑ` (instead of `tau_e`).
They take a bit longer to input, but as code is read more than it is written, the improvement in readability is worth it.
See [here](https://docs.julialang.org/en/v1/manual/unicode-input/)
for how to input many unicode characters in Julia environments (like in Jupyter notebooks with IJulia, or in VS Code).


## How to hack on the code

Make a file in `test/` that uses the edited package code, then
```julia
pkg> activate .
julia> using Revise
julia> include("text/file.jl")
```
