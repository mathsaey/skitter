# Used by "mix format"
[
  line_length: 80,
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    spit: :*,
    effect: :*,
    instance: :*,
    instance!: :*,
    component: :*,
    inject_error: :*,
    internal_state: :*,
    external_effects: :*
  ]
]
