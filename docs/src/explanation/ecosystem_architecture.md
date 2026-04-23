# Ecosystem Architecture

Why QPSTools is a thin lab layer on top of registered, general-purpose packages — and how method dispatch threads the layers together without re-exports.

!!! note "TODO"
    Write this explainer. Should cover the three-layer split (Models → Analysis → Application), why QPSTools stays private while SpectroscopyTools is (will be) registered, and the `import ...: fn` pattern for extending sibling functions via new method dispatches on `AnnotatedSpectrum`.
