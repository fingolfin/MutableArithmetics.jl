#  Copyright 2019, Gilles Peiffer, Benoît Legat, Sascha Timme, and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.
#############################################################################

module MutableArithmetics

# Performance note:
# We use `Vararg` instead of splatting `...` as using `where N` forces Julia to
# specialize in the number of arguments `N`. Otherwise, we get allocations and
# slowdown because it compiles something that works for any `N`. See
# https://github.com/JuliaLang/julia/issues/32761 for details.

"""
    add_mul(a, args...)

Return `a + *(args...)`. Note that `add_mul(a, b, c) = muladd(b, c, a)`.
"""
function add_mul end
add_mul(a, b) = a + b
add_mul(a, b, c) = muladd(b, c, a)
add_mul(a, b, c::Vararg{Any, N}) where {N} = add_mul(a, b *(c...))

"""
    iszero!(x)

Return a `Bool` indicating whether `x` is zero, possibly modifying `x`.

## Examples

In MathOptInterface, a `ScalarAffineFunction` may contain duplicate terms.
In `Base.iszero`, duplicate terms need to be merged but the function is left
with duplicates as it cannot be modified. If `iszero!` is called instead,
the function will be canonicalized in addition for checking whether it is zero.
"""
iszero!(x) = iszero(x)

include("interface.jl")
include("shortcuts.jl")
include("broadcast.jl")

# Implementation of the interface for Base types
import LinearAlgebra
const Scaling = Union{Number, LinearAlgebra.UniformScaling}
scaling(x::Scaling) = x
function scaling_convert(::Type{LinearAlgebra.UniformScaling{T}}, x::LinearAlgebra.UniformScaling) where T
    # `convert(::Type{<:UniformScaling}, ::UniformScaling)` is not defined in LinearAlgebra.
    return LinearAlgebra.UniformScaling(convert(T, x.λ))
end
scaling_convert(T::Type, x::LinearAlgebra.UniformScaling) = convert(T, x.λ)
scaling_convert(T::Type, x) = convert(T, x)
include("bigint.jl")
include("bigfloat.jl")
include("linear_algebra.jl")
include("sparse_arrays.jl")

"""
    isequal_canonical(a, b)

Return whether `a` and `b` represent a same object, even if their
representations differ.

## Examples

The terms in two MathOptInterface affine functions may not match but once
the duplicates are merged, the zero terms are removed and the terms are sorted
in ascending order of variable indices (i.e. their canonical representation),
the equality of the representation is equivalent to the equality of the objects
begin represented.
"""
isequal_canonical(a, b) = a == b
function isequal_canonical(a::AT, b::AT) where AT <: Union{Array, LinearAlgebra.Symmetric, LinearAlgebra.UpperTriangular, LinearAlgebra.LowerTriangular}
    return all(zip(a, b)) do elements
        return isequal_canonical(elements...)
    end
end
function isequal_canonical(x::LinearAlgebra.Adjoint, y::LinearAlgebra.Adjoint)
    return isequal_canonical(parent(x), parent(y))
end
function isequal_canonical(x::LinearAlgebra.Transpose, y::LinearAlgebra.Transpose)
    return isequal_canonical(parent(x), parent(y))
end
function isequal_canonical(x::LinearAlgebra.Diagonal, y::LinearAlgebra.Diagonal)
    return isequal_canonical(parent(x), parent(y))
end
function isequal_canonical(x::LinearAlgebra.Tridiagonal, y::LinearAlgebra.Tridiagonal)
    return isequal_canonical(x.dl, y.dl) && isequal_canonical(x.d, y.d) && isequal_canonical(x.du, y.du)
end

include("rewrite.jl")
include("dispatch.jl")

# Test that can be used to test an implementation of the interface
include("Test/Test.jl")


end # module
