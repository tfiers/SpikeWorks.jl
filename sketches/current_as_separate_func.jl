# Conductance-based synaptic current
Iₛ(n::CobaIzhNeuron) = let (; v, gₑ, gᵢ) = n
    gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
end
#
# or:
synaptic_current(n::CobaIzhNeuron) =
    let (; v, gₑ, gᵢ) = n

        gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
    end
# or:
synaptic_current(n::CobaIzhNeuron) = n.gₑ * (n.v - Eₑ) + n.gᵢ * (n.v - Eᵢ)
#
# or: not a separate func, but inline as it is now in ../test/Nto1sim.jl
# if we _would_ use a sep func, then the line in update! would be:
Dₜ.v = (k*(v-vₗ)*(v-vₜ) - u - synaptic_current(n)) / C
#
# that's ugly mix :) (of math and programming longnames)
# you could do
Iₛ = synaptic_current(n)
Dₜ.v = (k*(v-vₗ)*(v-vₜ) - u - Iₛ) / C
