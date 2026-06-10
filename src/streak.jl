# Streak-camera PL loader: annotated wrapper around HamamatsuStreakFiles.StreakImage
#
# Mirrors the JASCOFiles integration pattern (see types.jl): the sibling
# package owns parsing; QPSTools wraps the result with sample metadata
# for display and eLabFTW auto-tagging.

"""
    StreakPL

Streak-camera PL measurement with attached sample metadata.

The 2D analogue of [`AnnotatedSpectrum`](@ref): wraps the raw `StreakImage`
from HamamatsuStreakFiles.jl together with the sample kwargs passed to
[`load_streak_pl`](@ref).

# Fields
- `data::StreakImage` — raw image from HamamatsuStreakFiles.jl
  (`wavelength × time → counts`, plus instrument metadata)
- `sample::Dict{String,Any}` — sample metadata (kwargs from loader)
- `path::String` — file path
"""
struct StreakPL
    data::StreakImage
    sample::Dict{String,Any}
    path::String
end

# Same accessor interface as AnnotatedSpectrum subtypes
spectrum_data(s::StreakPL) = s.data
sample_metadata(s::StreakPL) = s.sample
sample_id(s::StreakPL) = get(s.sample, "_id", "unknown")

Base.size(s::StreakPL) = size(s.data)

function Base.show(io::IO, s::StreakPL)
    print(io, "StreakPL(")
    show(io, s.data)
    print(io, ")")
end

function Base.show(io::IO, mime::MIME"text/plain", s::StreakPL)
    println(io, "StreakPL — ", basename(s.path))
    show(io, mime, s.data)
    if !isempty(s.sample)
        print(io, "\n  Sample:       ")
        print(io, join(("$k = $v" for (k, v) in sort(collect(s.sample))), ", "))
    end
end

"""
    load_streak_pl(path::String; kwargs...) -> StreakPL

Load a Hamamatsu HPD-TA/HiPic `.img` streak-camera PL file.

Any kwargs are stored in the sample dict for display and eLabFTW tagging.
The raw image is available as `.data` (a `StreakImage` from
HamamatsuStreakFiles.jl); wavelength order on disk (commonly descending)
is preserved.

# Example
```julia
pl = load_streak_pl("data/PL/15K.img"; temperature="15K", material="NH4SCN")
plot_streak_pl(pl)
```
"""
function load_streak_pl(path::String; kwargs...)
    full_path = abspath(path)
    isfile(full_path) || error("File not found: $full_path")
    img = StreakImage(full_path)
    sample = Dict{String, Any}(string(k) => v for (k, v) in kwargs)
    return StreakPL(img, sample, full_path)
end
