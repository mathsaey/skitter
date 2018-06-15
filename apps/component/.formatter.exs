# Used by "mix format"
[
  line_length: 80,
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    spit: :*,
    throw: :*,
    error: :*,
    effect: :*,
    fields: :*,
    instance: :*,
    instance!: :*,
    component: :*,
    inject_error: :*,
    state_change: :*,
    external_effect: :*
  ]
]
