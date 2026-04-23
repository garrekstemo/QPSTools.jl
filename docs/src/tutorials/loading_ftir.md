# Loading FTIR Spectra

A cross-package walkthrough: load a JASCO FTIR spectrum with QPSTools, correct the baseline with SpectroscopyTools, fit the peaks, and log the result to eLabFTW.

!!! note "TODO"
    Write this tutorial. Should cover `load_spectroscopy` auto-dispatch on JASCO files, wrapping in `AnnotatedSpectrum`, handing off to `correct_baseline` and `fit_peaks` (SpectroscopyTools), and finishing with `log_to_elab`.
