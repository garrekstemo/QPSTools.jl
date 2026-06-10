# Synthetic Hamamatsu .img streak fixture (ported from HamamatsuStreakFiles'
# test suite, simplified to the valid-file case).
#
# Produces a 4 wavelength × 3 time UInt16 image with a descending-nm X table
# (700 → 670), an ascending-ns Y table (0, 2, 4), counts 1:12, and an INI
# comment block carrying the instrument metadata QPSTools surfaces in
# eLabFTW provenance.

function make_streak_fixture(path::String)
    comment_len = 512
    width, height = 4, 3
    xscale = Float32[700, 690, 680, 670]
    yscale = Float32[0, 2, 4]

    img = collect(reinterpret(UInt8, htol.(UInt16.(1:width*height))))
    img_start = 64 + comment_len
    xoff = img_start + length(img)
    yoff = xoff + 4 * length(xscale)
    comment =
        "[Application],Date=\"2026/06/02\",Time=\"13:17:16.967\",Software=\"HPD-TA\"" *
        "[Camera],CameraName=\"C11440-36U\"" *
        "[Acquisition],NrExposure=100,ExposureTime=14 ms,ZAxisLabel=Intensity," *
        "ZAxisUnit=Count,areSource=\"0,0,$width,$height\"" *
        "[Streak camera],DeviceName=\"C10910\",Time Range=\"50 ns\"" *
        "[Spectrograph],Wavelength=\"554.969\",Grating=\"50 g/mm\"" *
        "[Scaling],ScalingXType=2,ScalingXScale=1,ScalingXUnit=\"nm\"," *
        "ScalingXScalingFile=\"#$xoff,$(length(xscale))\",ScalingYType=2,ScalingYScale=1," *
        "ScalingYUnit=\"ns\",ScalingYScalingFile=\"#$yoff,$(length(yscale))\""
    @assert length(comment) <= comment_len

    hdr = zeros(UInt8, 64)
    hdr[1:2] = codeunits("IM")
    hdr[3:4] = reinterpret(UInt8, [htol(UInt16(comment_len))])
    hdr[5:6] = reinterpret(UInt8, [htol(UInt16(width))])
    hdr[7:8] = reinterpret(UInt8, [htol(UInt16(height))])
    hdr[13:14] = reinterpret(UInt8, [htol(UInt16(2))])  # type 2 = UInt16 pixels

    bytes = vcat(hdr, Vector{UInt8}(rpad(comment, comment_len, ' ')), img)
    append!(bytes, reinterpret(UInt8, htol.(xscale)))
    append!(bytes, reinterpret(UInt8, htol.(yscale)))

    write(path, bytes)
    return path
end
