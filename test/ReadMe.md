# Firework tests

At the moment, these scripts are not automated tests yet, but more example user code, to use for debugging, or to experiment with the API.

Note that `Firework` itself is not in this `test/` dir's `Project.toml`.
It gets added automatically on running `] test` in the root dir.

If we would add it to `Project.toml` here, we get `ERROR: can not merge projects`
on `] test`. ([Pkg.jl issue 1585](https://github.com/JuliaLang/Pkg.jl/issues/1585#issuecomment-875684010)).
