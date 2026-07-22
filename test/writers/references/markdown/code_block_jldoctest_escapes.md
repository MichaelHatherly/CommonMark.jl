```jldoctest; filter="a\\.b"
julia> a = 1
1
```

```jldoctest
julia> name = :hello; @varname(x.\$name)
x.hello
```
