
# Some syntax sketches.


# Nto1

m = @model begin

    n   = 1 * izh
    pₑ  = Nₑ * PoissonInput(λ)
    pᵢ  = Nᵢ * PoissonInput(λ)

    pₑ => n  @on_pre gₑ += Δgₑ
    pᵢ => n  @on_pre gᵢ += Δgᵢ
end

m = @model begin

    n   = 1 * izh
    Pₑ  = Nₑ * PoissonInput(λ)
    Pᵢ  = Nᵢ * PoissonInput(λ)

    connect(Pₑ => n, on_pre = :( gₑ += Δgₑ ))
    connect(Pᵢ => n, on_pre = :( gᵢ += Δgᵢ ))
end



# RNN

m = @model begin
    nₑ = Nₑ * izh
    nᵢ = Nᵢ * izh
    sₑ = connect(nₑ => (nₑ & nᵢ), p_conn, on_pre = :( post.gₑ += w ))
    sᵢ = connect(nᵢ => (nₑ & nᵢ), p_conn, on_pre = :( post.gᵢ += w ))
end

m = @model begin

    # Neurons
    nₑ = Nₑ * izh
    nᵢ = Nᵢ * izh
    n  = nₑ + nᵢ

    # Connections
    cₑ = connect(nₑ => n, p_conn, t_axon)
    cᵢ = connect(nᵢ => n, p_conn, t_axon)

    @on_spike_arrival
    cₑ  =>  post.gₑ += w
    cᵢ  =>  post.gᵢ += w
end




m = @model begin

    # Neurons
    nₑ = Nₑ * izh_neuron
    nᵢ = Nᵢ * izh_neuron
    n  = nₑ + nᵢ

    # Connections
    c = cₑ + cᵢ
    cₑ = connect(nₑ => n)
    cᵢ = connect(nᵢ => n)
    c.p_conn   = …
    c.tx_delay = …

    cₑ.@on_spike_arrival(post.gₑ += w)
    cᵢ.@on_spike_arrival(post.gᵢ += w)
end

# hm, confusing to just do *


    cₑ.@on_spike_arrival(izh_neuron.gₑ += w)
    cᵢ.@on_spike_arrival(izh_neuron.gᵢ += w)


# I like this (the `=> (nₑ & nᵢ`):

    # Neurons
    nₑ = Nₑ * izh_neuron
    nᵢ = Nᵢ * izh_neuron
    # Connections
    cₑ = connect(nₑ => (nₑ & nᵢ))
    cᵢ = connect(nᵢ => (nₑ & nᵢ))

# Aha! the post.gₑ stuff should already be there at the neuron def.
# (otherwise they're same as each other, "why you make diff here?").
#
# So.. what a neuron does to its outputs is property of that neuron,
# not the connection (Dale's law, ig).

# Oh! so it should.. be in the `@spike if …` block...
# hm, but then how to differentiate huh.
# I mean, how to DRY inh vs exc there.
# ig you'd separate spike condition and effects.
# so sth like
izh = f(diffeqs, spike_condition, after_spike: v=vₛ & u+=Δu)
izh_exc = similar(izh)
izh_exc.after_spike_arrives_at_output_neuron(output_neuron.gₑ += Δgₑ)
# yee.
# (:) breakthrough).

# mayb:
izh = @eqs begin

    dv/dt = (k*(v-vᵣ)*(v-vₜ) - u - I_syn + I_ext) / C
    …

    @spike if v > v_peak
        v = v_reset
        u += Δu

        @after axon_delay begin
            for on in output_neurons
                on.gₑ += Δg
            end
        end
    end
end
# (Ok, but we went back to ignoring exc/inh split problem here).

# ooh. that `@after delay` thing should be like a scheduled task in julia.
# (hehehe, more abuse).
# (cause now it looks like the `if` content will block execution, kinda).
# https://docs.julialang.org/en/v1/manual/asynchronous-programming/
# so yeah sth, mayb:
for on in output_neurons
    @async begin
        @wait sleep(axon_delay(self => on))
        on.gₑ += Δg
    end
end


# ah, the izh vs izh_exc split we could do with:

izh = @eqs begin
    dv/dt = (k*(v-vᵣ)*(v-vₜ) - u - I_syn + I_ext) / C
    …
    spike = v > vₛ
    if spike
        v = v_reset
        u += Δu
    end
end

izh_exc = @eqs begin

    $izh

    if spike
        # the above `for on in output_neurons` spiel;
        # --but that should be provided by lib...
    end
end
# hm so maybe we can keep our `@spike if v > vₛ`.
#
# there is syntax for providing a closure, and giving it an arg:

izh_exc.on_spike.after_axon_delay() do output_neuron
    output_neuron.gₑ += Δgₑ
end
# (starting to like more and more :)).

# btw a function "copy these eqs but add this" would be nice.
# (so you don't need the extra line of `izh_exc = copy(izh); izh_exc.prop = `).

# I gotta admit though, the `izh_exc.on_spike` above feels ambiguous: pre or post spike.
# So in that case, yes, spike events make sense to be on the connections after all.

# maybe sth like `on_self_spike` ? (i kinda like!)
# So the whole thing'd be:
# [stashing, ct here]

# a good name mayb:
izh.after_spike_arrives_at_output() do
    ...
end





# -----------------------------------------------------------------------------------------

# The above.. (I don't like it)
# explicit is better than implicit.
# so:
n = NeuronGroup(N, izhikevich_equations)
nₑ = n[1:Nₑ]
nᵢ = n[Nₑ+1:end]
# (I like)
# Now, for both these groups to define what happens
# at their output synapses.
nₑ.output_synapses.on_pre_spike
# no. ambiguous again.
# Guess we have to go indeed the brian way:
# synapse affect!s are property of synapse, not neuron.
e_synapses = connect(nₑ => n)
i_synapses = connect(nᵢ => n)
# ooh yes, this is much better :)
e_synapses.on_pre_spike! = (pre, post, syn) = (post.gₑ += syn.w)
i_synapses.on_pre_spike! = (pre, post, syn) = (post.gᵢ += syn.w)
#
#
# Some variations:
# Verbose
neurons = NeuronGroup(N, izhikevich_equations)
e_neurons = neurons[1:Nₑ]
i_neurons = neurons[Nₑ+1:end]
e_synapses = connect(e_neurons => neurons)
i_synapses = connect(i_neurons => neurons)
e_synapses.on_pre_spike! = (pre, post, syn) = (post.gₑ += syn.w)
i_synapses.on_pre_spike! = (pre, post, syn) = (post.gᵢ += syn.w)
#
# All short
n = NeuronGroup(N, izhikevich_equations)
nₑ = n[1:Nₑ]
nᵢ = n[Nₑ+1:end]
sₑ = connect(nₑ => n)
sᵢ = connect(nᵢ => n)
sₑ.on_pre_spike! = (pre, post, syn) = (post.gₑ += syn.w)
sᵢ.on_pre_spike! = (pre, post, syn) = (post.gᵢ += syn.w)
#
# With f integrated in connect
n = NeuronGroup(N, izhikevich_equations)
nₑ = n[1:Nₑ]
nᵢ = n[Nₑ+1:end]
sₑ = connect(nₑ => n; on_pre = :(post.gₑ += syn.w) )
sᵢ = connect(nᵢ => n; on_pre = :(post.gᵢ += syn.w) )
#
# Middle ground
# ..
# (forgotten in the above: `connect(…, p_conn)`)

# After those defs, we can pass em:
simulate([n, sₑ, sᵢ])
# or
simulate(neurons=[n], synapses=[sₑ, sᵢ])


# A more natural way for all that↑ might be:
n = NeuronGroup(N, izhikevich_equations)
nₑ = n[1:Nₑ]
nᵢ = n[Nₑ+1:end]
syn = connect_recurrently(n)
syn.on_pre_spike! = @f begin
    if n ∈ nₑ
        post.gₑ += syn.w
    elseif n ∈ nᵢ
        post.gᵢ += syn.w
    end
end
#
# or indeed
# (and we're back where we started):
syn.on_pre_spike! = @f begin
    if is_excitatory(pre)
        post.gₑ += syn.w
    elseif is_inhibitory(pre)
        post.gᵢ += syn.w
    end
end
#
# going further (dryer, ig), sth like
on_spike_arrival!(pre, post, syn) =
    var = if     (pre ∈ nₑ)  post.gₑ
          elseif (pre ∈ nᵢ)  post.gᵢ
          end
    var += syn.Δg
end
# or ok
on_spike_arrival!(pre, post) =
    if     (pre ∈ nₑ)  post.gₑ += Δg
    elseif (pre ∈ nᵢ)  post.gᵢ += Δg
    end
#
# (This is very clear, I like it lots. Insight in the model :)).

# Question ofc is, what is most efficient implementation.
# But that is diff q than "what is best human repr"
# (Though ofc ideal if same)


# As a summary, best we have now:
# [izh eqs]
neurons = NeuronGroup(N, izhikevich_equations)
synapses = connect_recurrently(neurons; p_conn, tx_delay)
nₑ = neurons[1:Nₑ]
nᵢ = neurons[Nₑ+1:end]
on_spike_arrival!(pre, post) =
    if     (pre ∈ nₑ)  post.gₑ += Δg
    elseif (pre ∈ nᵢ)  post.gᵢ += Δg
    end

simulate(neurons, synapses, on_spike_arrival!)


# Or:
neurons = NeuronGroup(N, izhikevich_equations)
nₑ, nᵢ = split(neurons, 4//1)
nₑ.type = :exc
nᵢ.type = :inh
on_spike_arrival!(pre, post) =
    if     (pre.type == :exc)  post.gₑ += Δg
    elseif (pre.type == :inh)  post.gᵢ += Δg
    end
synapses = connect_recurrently(neurons; p_conn, tx_delay, on_spike_arrival!)
# or
synapses = connect_recurrently(neurons; p_conn, tx_delay) do (pre, post)
    if     (pre.type == :exc)  post.gₑ += Δg
    elseif (pre.type == :inh)  post.gᵢ += Δg
    end
end
# or
synapses = connect_recurrently(neurons; p_conn, tx_delay, on_pre = @f begin
    if     (pre.type == :exc)  post.gₑ += Δg
    elseif (pre.type == :inh)  post.gᵢ += Δg
    end
end)
# or
synapses = connect_recurrently(neurons; p_conn, tx_delay, on_pre = @f begin
    if     (pre.type == :exc)  post.gₑ += Δg
    elseif (pre.type == :inh)  post.gᵢ += Δg
    end
end)
# (to continue: "maybe a macro?")
#
# then finally
simulate(neurons, synapses, on_spike_arrival!)


# Riffing on the n.type:
neurons = NeuronGroup(N, izhikevich_equations)
# and then
ntype = fill(:exc, N)
ntype[1:Nᵢ] = :inh
# or
ntype = similar(neurons, Symbol)
ntype[1:Nₑ]     = :exc
ntype[Nₑ+1:end] = :inh
# or
ntype = similar(neurons, Symbol)
ntype[1:Nₑ]       = :exc
ntype[end-Nᵢ:end] = :inh
# and then
on_spike_arrival!(pre, post) =
    if     (ntype[pre] == :exc)  post.gₑ += Δg
    elseif (ntype[pre] == :inh)  post.gᵢ += Δg
    end
synapses = connect_recurrently(neurons; p_conn, tx_delay, on_spike_arrival!)


# Or simpler alternatives:
#a
neurons = NeuronGroup(N, izhikevich_equations)
nₑ = neurons[1:Nₑ]
nᵢ = neurons[Nₑ+1:end]
nₑ.type = :exc
nᵢ.type = :inh
#b
neurons = NeuronGroup(N, izhikevich_equations)
neurons[1:Nₑ].type     = :exc
neurons[Nₑ+1:end].type = :inh
#
# and then
on_spike_arrival!(pre, post) =
    if     (pre.type == :exc)  post.gₑ += Δg
    elseif (pre.type == :inh)  post.gᵢ += Δg
    end
synapses = connect_recurrently(neurons; p_conn, tx_delay, on_spike_arrival!)

#
# hah, simplest here would be to do look at index:
neurons = NeuronGroup(N, izhikevich_equations)
on_spike_arrival!(pre, post) =
    if (pre.i ≤ Nₑ)  post.gₑ += Δg
    else             post.gᵢ += Δg
    end
# Hm but this is not readable/clear.


# Alternatives with else:
# a
neurons = NeuronGroup(N, izhikevich_equations)
nₑ, nᵢ = split(neurons, 4//1)
on_spike_arrival! = @func
    if (pre ∈ nₑ)  post.gₑ += Δg
    else           post.gᵢ += Δg
    end
synapses = connect_recurrently(neurons; p_conn, tx_delay, on_spike_arrival!)
# This lean @func is new. and i like it.
#
# b
neurons = NeuronGroup(N, izhikevich_equations)
is_excitatory = Dict([n => (i ≤ Nₑ) for (i, n) in enumerate(neurons)])
on_spike_arrival! = @func
    if is_excitatory(pre)  post.gₑ += Δg
    else                   post.gᵢ += Δg
    end
synapses = connect_recurrently(neurons; p_conn, tx_delay, on_spike_arrival!)
# I like the explicit counting here :)


# Ah, a (beautifully 'functional' :)) synthesis:
neurons = NeuronGroup(N, izhikevich_equations)
type(neuron) = if (neuron.index ≤ Nₑ)  :exc
               else                    :inh
               end
on_spike_arrival = @func
    if type(pre) == :exc  post.gₑ += Δg
    else                  post.gᵢ += Δg
    end
# This _should_ be optimized like mad,
# optimized to just the `if (pre.i ≤ Nₑ)  post.gₑ += Δg` of above

# (shorter version of type:)
type(neuron) = (neuron.index ≤ Nₑ) ? :exc : :inh





# -----------------------------------------------------------------------------------------

# Actually, when simulating multiple izh neurons, you have vecs of variables.
# (alternative is to indeed have diff `neuron` structs, each with it's own `neuron.gₑ` etc).
# but if so, then:
on_spike_arrival = @func
    if type(pre) == :exc  gₑ[post] += Δg
    else                  gᵢ[post] += Δg
    end
# and `post` etc are just integers.
#
# This is actually clearer too :o


# With more clarity on that pre is an index:
neurons = NeuronGroup(N, izhikevich_equations)
neuron_type(i) = if (i ≤ Nₑ)  :exc
                 else         :inh
                 end
on_spike_arrival = @func
    if (neuron_type(pre) == :exc)  gₑ[post] += Δg
    else                           gᵢ[post] += Δg
    end


# with match macro:
on_spike_arrival = @func @switch neuron_type(pre) begin
    :exc => gₑ[post] += Δg
    :inh => gᵢ[post] += Δg
end
# yeah nah, plain if better.
