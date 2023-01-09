
module Units

using ..SpikeWorks: @export_all, @constants

@export_all @constants begin

    giga  = 1e9
    mega  = 1e6
    kilo  = 1e3
    milli = 1e-3
    centi = 1e-2
    micro = 1e-6
    nano  = 1e-9
    pico  = 1e-12

    second = 1.0
    Hz = 1 / second
    ms = milli * second
    minute = 60 * second
    hour = 60 * minute

    seconds = second
    minutes = minute
    hours = hour
    # Plural makes more sense in e.g. `10minutes`.
    # Singular makes more sense in `f(x, unit = minute)` or `x = 10 * minute`.

    metre = 1.0
    meter = metre
    cm = centi * metre
    mm = milli * metre
    μm = micro * metre
    nm = nano * metre

    ampere = 1.0
    mA = milli * ampere
    μA = micro * ampere
    nA = nano * ampere
    pA = pico * ampere

    volt = 1.0
    mV = milli * volt
    μV = micro * volt
    nV = nano * volt

    siemens = ampere / volt
    ohm = 1 / siemens
    mS = milli * siemens
    nS = nano * siemens
    pS = pico * siemens
    Mohm = mega * ohm
    Gohm = giga * ohm

    coulomb = ampere * second
    farad = coulomb / volt
    μF = micro * farad
    nF = nano * farad
    pF = pico * farad
end

end # module
