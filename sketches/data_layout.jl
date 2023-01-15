# Mutable or immutable structs?
# StructVector?
# Let's benchmark.

# Recording a useful bit from roam exploration here:
#
unsafe_pointer_from_objectref(@nospecialize(x)) =
    ccall(:jl_value_ptr, Ptr{Cvoid}, (Any,), x)
#
# Shows that fields of a mutable struct are scattered around!

# Normal (built-in, exported) `pointer_from_objref`
# for els of vec, shows that (even mut values) are stored contiguously :)


# Now, for comparison
using BenchmarkTools




mutable struct NeuronMut
    v::Float64
    u::Float64
end

v_of_mut = [
    NeuronMut(randn(), randn())
    for _ in 1:10_000
]
pointer_from_objref(v_of_mut[1])  # @0x000000000d54f8d0
pointer_from_objref(v_of_mut[2])  # @0x000000000d54f8f0

ptr(x) = x |> unsafe_pointer_from_objectref |> Int
distance(x, y) = ptr(y) - ptr(x)  # bytes I suppose

distance(v_of_mut[1], v_of_mut[2])  # 32
sizeof(NeuronMut)                   # 16 (bytes)
distance(v_of_mut[1], v_of_mut[3])  # 64

n = NeuronMut(1,1)
unsafe_pointer_from_objectref(n)   # @0x000000000a815670
unsafe_pointer_from_objectref(n.v) # @0x00000000717f6500  -- but it changes on each call :)
unsafe_pointer_from_objectref(n.u) # @0x00000000718e5aa0  -- (same)

struct NeuronImm
    v::Float64
    u::Float64
end
v_of_imm = [
    NeuronImm(randn(), randn())
    for _ in 1:10_000
]
ni = NeuronImm(1,1)
unsafe_pointer_from_objectref(ni)    # @0x000000000c38c070
unsafe_pointer_from_objectref(ni.v)  # @0x000000000b07c7b0 -- again! changes errytime.
unsafe_pointer_from_objectref(ni.u)  # @0x000000000b07dca0
# distance(ni.v, ni.u)  # always 0, for some reason

on_self_spike!(n::NeuronMut) = begin
    n.v = 0
    n.u += 2
    n
end

@btime begin
    for n in $v_of_mut
        on_self_spike!(n)
    end
end
# BenchmarkTools.Trial: 10000 samples with 1 evaluation.
#  Range (min … max):  11.000 μs … 124.700 μs  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     13.100 μs               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   14.488 μs ±   3.488 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%
#
#         █▅▃             ▄
#   ▂▂▁▃▃▄████▁▁▄▃▁▁▁▁▁▁▄▇██▂▂▃▂▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ ▂
#   11 μs           Histogram: frequency by time         24.7 μs <
#
#  Memory estimate: 0 bytes, allocs estimate: 0.


fillbuf!(buf::NeuronMut, data::NeuronImm) = begin
    buf.v = data.v
    buf.u = data.u
end
NeuronImm(n::NeuronMut) = NeuronImm(n.v, n.u)

@btime begin
    b = NeuronMut(0,0)
    for i in eachindex($v_of_imm)
        n = $v_of_imm[i]
        fillbuf!(b, n)
        on_self_spike!(b)
        n = NeuronImm(b)
        $v_of_imm[i] = n
    end
end
# BenchmarkTools.Trial: 10000 samples with 5 evaluations.
#  Range (min … max):  6.000 μs … 24.120 μs  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     6.740 μs              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   7.159 μs ±  1.115 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%
#
#    ▂ ▄▂▅▂█▃▅▁▁ ▁ ▁▁▂▂▂▁▁▁     ▁      ▁                       ▁
#   ███████████████████████▇█████▇▇██▇▇█▇▆▇▆▆▅▆▆▇▅▆▆▇▆▇▅▅▆▆▆▅▅ █
#   6 μs         Histogram: log(frequency) by time     11.7 μs <
#
#  Memory estimate: 0 bytes, allocs estimate: 0.

shorterloop() = begin  # not real, just for syntax hl lol

    v_of_imm[i] = NeuronImm(on_self_spike!(fillbuf!(b, v_of_imm[i])))
    # or
    v_of_imm[i] = v_of_imm[i] |> fillbuf |> on_self_spike! |> NeuronImm
end



# Diff, now in func

function fmut()
    for n in v_of_mut
        on_self_spike!(n)
    end
end
@btime fmut()
# BenchmarkTools.Trial: 7799 samples with 1 evaluation.
#  Range (min … max):  507.000 μs …   4.276 ms  ┊ GC (min … max): 0.00% … 74.41%
#  Time  (median):     598.600 μs               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   637.538 μs ± 235.518 μs  ┊ GC (mean ± σ):  3.50% ±  7.74%
#
#    ▄█▆▃▂▂▁                                                      ▁
#   ▇██████████▆▆▅▅▄▆▆▅▅▆▅▄▅▁▄▃▃▁▃▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▄ █
#   507 μs        Histogram: log(frequency) by time       2.61 ms <
#
#  Memory estimate: 460.78 KiB, allocs estimate: 19490.


function fimm()
    b = NeuronMut(0,0)
    for i in eachindex(v_of_imm)
        n = v_of_imm[i]
        fillbuf!(b, n)
        on_self_spike!(b)
        n = NeuronImm(b)
        v_of_imm[i] = n
    end
end
@btime fimm()
# BenchmarkTools.Trial: 3403 samples with 1 evaluation.
#  Range (min … max):  1.197 ms …   4.955 ms  ┊ GC (min … max): 0.00% … 50.19%
#  Time  (median):     1.364 ms               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   1.464 ms ± 411.929 μs  ┊ GC (mean ± σ):  4.12% ±  9.89%
#
#    ▂▄██▄▃▂▁▁                                                  ▁
#   ▇███████████▇▇▆▇▇▆▆▃▅▅▅▄▅▆▁▅▆▄▅▅▃▅▃▄▃▃▃▅▃▄▄▁▃▁▁▁▃▃▁▄▃▁▄▇▆█▇ █
#   1.2 ms       Histogram: log(frequency) by time       3.6 ms <
#
#  Memory estimate: 1.21 MiB, allocs estimate: 48979.

# Ok! So it is slower, the fancy idea.
# Well that's good news ig (simplest, most readable solution, works best)
# For comparison, let's try with pure vec..


v_of_vecs = [
    [randn(), randn()]
    for _ in 1:10_000
];
on_self_spike!(n::AbstractVector) = begin
    n[1] = 0  # v
    n[2] += 2  # u
end

function fvec()
    for n in v_of_vecs
        on_self_spike!(n)
    end
end
@btime fvec()
# BenchmarkTools.Trial: 4957 samples with 1 evaluation.
# Range (min … max):  742.900 μs …  31.599 ms  ┊ GC (min … max): 0.00% … 0.00%
# Time  (median):     895.800 μs               ┊ GC (median):    0.00%
# Time  (mean ± σ):     1.002 ms ± 572.225 μs  ┊ GC (mean ± σ):  3.29% ± 8.18%
#
#    ▄█▆▅▄▃▃▂▂▂▁                                                 ▁
#  ▆██████████████▇█▇▆▇▆▆▆▆▆▆▅▆▆▅▄▅▃▆▅▆▅▃▅▄▃▅▃▃▄▃▄▁▁▁▃▃▄▁▁▁▃▁▆▅▇ █
#  743 μs        Histogram: log(frequency) by time       3.12 ms <
#
# Memory estimate: 617.03 KiB, allocs estimate: 29490.

# Woahh!!!
# (fucking cr)
# So, mutable struct wins over all.
# Good news, but. djeez, grr.



# Aha, but wait :)
# StaticVec time
using StaticArrays
# ↪ Confusing: `SVector` is not statically sized vector;
#   It's immutable data vector rather.
#   For statically sized, but mutable, they have 'MVector'

v_of_statvecs = [
    MVector(randn(), randn())
    for _ in 1:10_000
];
function fstatvec()
    for n in v_of_statvecs
        on_self_spike!(n)
    end
end
@btime fstatvec()
# BenchmarkTools.Trial: 5553 samples with 1 evaluation.
#  Range (min … max):  725.600 μs …   5.971 ms  ┊ GC (min … max): 0.00% … 69.52%
#  Time  (median):     834.100 μs               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   895.956 μs ± 340.209 μs  ┊ GC (mean ± σ):  3.57% ±  7.83%

#   ▂▇█▅▃▂▂▁▁                                                     ▁
#   ████████████▇▆▄▅▄▅▃▄▆▄▃▁▄▄▁▄▄▅▄▃▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▃▃ █
#   726 μs        Histogram: log(frequency) by time        3.7 ms <

#  Memory estimate: 617.03 KiB, allocs estimate: 29490.

# Holy shit, dit is slower?
# __Our mutable struct wins again__??!!
# nice :)


# julia> versioninfo()
# Julia Version 1.8.1
# Commit afb6c60d69 (2022-09-06 15:09 UTC)
# Platform Info:
#   OS: Windows (x86_64-w64-mingw32)
#   CPU: 8 × Intel(R) Core(TM) i7-10510U CPU @ 1.80GHz
#   WORD_SIZE: 64
#   LIBM: libopenlibm
#   LLVM: libLLVM-13.0.1 (ORCJIT, skylake)
#   Threads: 7 on 8 virtual cores
# Environment:
#   JULIA_EDITOR = code.cmd
#   JULIA_NUM_THREADS = 7



# (btw, next time just use @btime: yes it "reports the minimum time";
#  but that's actually fine (tested with above examples here: same
#  results as with full @benchmark))

# (after resetting v_of_'s):

# julia> @btime fmut()
#   598.100 μs (19490 allocations: 460.78 KiB)

# julia> @btime fimm()
#   1.152 ms (48979 allocations: 1.21 MiB)

# julia> @btime fvec()
#   816.000 μs (29490 allocations: 617.03 KiB)

# julia> @btime fstatvec()
#   749.000 μs (29490 allocations: 617.03 KiB)



# Hello we're back.
# Let's try MutableNamedTuple
using MutableNamedTuples

on_self_spike!(n) = begin
    n.v = 0
    n.u += 2
end

v_of_MNTs = [
    MutableNamedTuple(v=randn(), u=randn())
    for _ in 1:10_000
];
function fmnt()
    for n in v_of_MNTs
        on_self_spike!(n)
    end
end
@btime fmnt()
#   1.031 ms (39490 allocations: 929.53 KiB)

# Hm, that's a pity

# reset v_of_MNTs, and
@benchmark fmnt()
# BenchmarkTools.Trial: 3806 samples with 1 evaluation.
#  Range (min … max):  987.700 μs …  20.634 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):       1.156 ms               ┊ GC (median):    0.00%
#  Time  (mean ± σ):     1.306 ms ± 703.571 μs  ┊ GC (mean ± σ):  4.96% ± 8.96%
#
#   ▂█▇▅▄▄▃▂▁▁                                                    ▁
#   ███████████▇▇▇▇▇▇▅▆▁▄▅▃▁▃▁▁▁▃▁▄▁▁▁▁▁▁▃▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▃▃▄▆▆ █
#   988 μs        Histogram: log(frequency) by time       5.73 ms <
#
#  Memory estimate: 929.53 KiB, allocs estimate: 39490
