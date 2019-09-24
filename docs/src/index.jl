# ## ScientificTypes

# A light-weight julia interface for implementing conventions about the
# scientific interpretation of data, and for performing type coercions
# enforcing those conventions.

# [![Build
# Status](https://travis-ci.com/alan-turing-institute/ScientificTypes.jl.svg?branch=master)](https://travis-ci.com/alan-turing-institute/ScientificTypes.jl)

# ScientificTypes provides:

# - A hierarchy of new julia types representing scientific data types
#   for use in method dispatch (eg, for trait values). Instances of
#   the types play no role:

using ScientificTypes, AbstractTrees
ScientificTypes.tree()

# - A single method `scitype` for articulating a convention about what
#   scientific type each julia object can represent. For example, one
#   might declare `scitype(::AbstractFloat) = Continuous`.

# - A default convention called *mlj*, based on optional dependencies
#   CategoricalArrays, ColorTypes, and Tables, which includes a convenience
#   method `coerce` for performing scientific type coercion on
#   AbstractVectors and columns of tabular data (any table
#   implementing the
#   [Tables.jl](https://github.com/JuliaData/Tables.jl) interface). A
#   table at the end of this document details the convention.

# - A `schema` method for tabular data, based on the optional Tables
#   dependency, for inspecting the machine and scientific types of
#   tabular data, in addition to column names and number of rows

# The only core dependencies of ScientificTypes are Requires and
# InteractiveUtils (from the standard library).

# ### Quick start

# Install with `using Pkg; add ScientificTypes`.

# Get the scientific type of some julia object, using the default
# convention:

scitype(3.14)


# #### Typical type coercion work-flow for tabular data

using CategoricalArrays, DataFrames, Tables
X = DataFrame(name=["Siri", "Robo", "Alexa", "Cortana"],
              height=[152, missing, 148, 163],
              rating=[1, 5, 2, 1])

#-

schema(X)

#-

schema(X).scitypes

#-

Xfixed = coerce(X, :name=>Multiclass,
                   :height=>Continuous,
                   :rating=>OrderedFactor);
#-

schema(Xfixed).scitypes

# Testing if each column of a table has an element scientific type
# that subtypes types from a specified list:

scitype(Xfixed) <: Table(Union{Missing,Continuous}, Finite)

# ### Notes

# - We regard the built-in julia type `Missing` as a scientific
#   type. The new scientific types introduced in the current package
#   are rooted in the abstract type `Found` (see tree above) and we
#   export the alias `Scientific = Union{Missing, Found}`.

# - `Finite{N}`, `Muliticlass{N}` and `OrderedFactor{N}` are all
#   parameterized by the number of levels `N`. We export the alias
#   `Binary = Finite{2}`.

# - `Image{W,H}`, `GrayImage{W,H}` and `ColorImage{W,H}` are all
#   parameterized by the image width and height dimensions, `(W, H)`.

# - The function `scitype` has the fallback value `Unknown`.

# - Since Tables is an optional dependency, the `scitype` of a
#   Tables.jl supported table is `Unknown` unless Tables has been imported.

# - Developers can define their own conventions using the code in
#   "src/conventions/mlj/" as a template. The active convention is
#   controlled by the value of `ScientificTypes.CONVENTION[1]`.


# ### Detailed usage examples

using ScientificTypes

# Activate a convention:

mlj() # redundant, as the default

#-

scitype(3.142)

#-

scitype((2.718, 42))

#-

using CategoricalArrays
v = categorical(['a', 'c', 'a', missing, 'b'], ordered=true)
scitype(v[1])

#-

scitype(v)

#-

v = [1, 2, missing, 3];
scitype(v)

#-

w = coerce(v, Multiclass);
scitype(w)

#-

using Tables
T = (x1=rand(10), x2=rand(10), x3=rand(10))
scitype(T)

#-

using DataFrames
X = DataFrame(x1=1:5, x2=6:10, x3=11:15, x4=[16, 17, missing, 19, 20]);

#-

scitype(X)

#-

schema(X)

#-

Xfixed = coerce(X, :x1=>Continuous,
                   :x2=>Continuous,
                   :x3=>Multiclass,
                   :x4=>OrderedFactor)
scitype(Xfixed)

#-

scitype(Xfixed) <: Table(Continuous, Finite)

#-

scitype(Xfixed) <: Table(Continuous, Union{Finite, Missing})


# ### The scientific type  of tuples, arrays and tables

# Note that under any convention, the scitype of a tuple is a `Tuple`
# type parameterized by scientific types:

scitype((1, 4.5))

# Similarly, the scitype of an `AbstractArray` object is
# `AbstractArray{U}`, where `U` is the union of the element scitypes:

scitype([1,2,3, missing])

# Provided the [Tables]() package is loaded, any table implementing
# the Tables interface has a scitype encoding the scitypes of its
# columns:

using CategoricalArrays
using Tables
X = (x1=rand(10),
     x2=rand(10),
     x3=categorical(rand("abc", 10)),
     x4=categorical(rand("01", 10)))
scitype(X)

# Specifically, if `X` has columns `c1, c2, ..., cn`, then, by definition,

# ```julia
# scitype(X) = Table{Union{scitype(c1), scitype(c2), ..., scitype(cn)}}
# ```

# With this definition, we can perform common type checks associated
# with tables. For example, to check that each column of `X` has an
# element scitype subtying either `Continuous` or `Finite` (but not
# `Union{Continuous, Finite}`!), we check

# ```julia
# scitype(X) <: Table{Union{AbstractVector{Continuous}, AbstractVector{<:Finite}}
# ```

# A built-in `Table` type constructor provides `Table(Continuous, Finite)` as
# shorthand for the right-hand side. More generally,

# ```julia
# scitype(X) <: Table(T1, T2, T3, ..., Tn)
#  ```

# if and only if `X` is a table and, for every column `col` of `X`,
# `scitype(col) <: AbstractVector{<:Tj}`, for some `j` between `1` and `n`:

scitype(X) <: Table(Continuous, Finite)

# Note that `Table(Continuous, Finite)` is a *type* union and not a
# `Table` *instance*.

# Detailed inspection of column scientific types is included in an
# extended form of Tables.schema:

schema(X)

#-

schema(X).scitypes

#-

typeof(schema(X))

# ### The *mlj* convention

# The table below summarizes the *mlj* convention for representing
# scientific types:

# `T`                               | `scitype(x)` for `x::T`                                                     | requires package
# ----------------------------------|:----------------------------------------------------------------------------|:------------------------
# `Missing`                         | `Missing`                                                                   |
# `AbstractFloat`                   | `Continuous`                                                                |
# `Integer`                         |  `Count`                                                                    |
# `CategoricalValue`                | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays
# `CategoricalString`               | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays
# `CategoricalValue`                | `OrderedFactor{N}` where `N = nlevels(x)`, provided `x.pool.ordered == true`| CategoricalArrays
# `CategoricalString`               | `OrderedFactor{N}` where `N = nlevels(x)` provided `x.pool.ordered == true` | CategoricalArrays
# `AbstractArray{<:Gray,2}`         | `GrayImage{W,H}` where `(W, H) = size(x)`                                   | ColorTypes
# `AbstractArrray{<:AbstractRGB,2}` | `ColorImage{W,H}` where `(W, H) = size(x)`                                  | ColorTypes
# any table type `T` supported by Tables.jl | `Table{K}` where `K=Union{column_scitypes...}`                      | Tables

# Here `nlevels(x) = length(levels(x.pool))`.


# #### Automatic type conversion

# The `autotype` function allows to use specific rules in order to guess appropriate
# scientific types for the data. Such rules would typically be more precise than the
# active convention. When `autotype` is used, a dictionary of suggested types is returned
# for each column in the data; if none of the specified rule applies, the ambient convention
# is used as "fallback".
#
# The function is called as:

autotype(X)

# If the keyword `only_changes` is passed set to `true`, then only the column names
# for which the suggested type is different from that provided by the convention are
# returned.

autotype(X; only_changes=true)

# To specify which rules are to be applied, use the `rules` keyword  and specify
# a tuple of symbols referring to specific rules; the default rule is `:few_to_finite`
# which applies a heuristic for columns which have relatively few values, these
# columns are then encoded with an appropriate `Finite` type.
# It is important to note that the order in which the rules are specified matters;
# rules will be applied in that order.

autotype(X; rules=(:few_to_finite,))

# Available rules are:
#
# Rule symbol      | scitype suggestion
# :--------------- | :---------------------------------
# :few_to_finite   | an appropriate finite type for columns with relatively few distinct values
# :discrete_to_continuous | Continuous type if the column type or scitype is discrete
# :string_to_class | Multiclass for any string-like column
#
# Autotype can be used in conjunction with `coerce`:

X_coerced = coerce(X, autotype(X))

# **Examples**
#
# By default it only applies the :few_to_many rule

n = 50
X = (a = rand("abc", n),         # 3 values, not number        --> Multiclass
     b = rand([1,2,3,4], n),     # 4 values, number            --> OrderedFactor
     c = rand([true,false], n),  # 2 values, number but only 2 --> Multiclass
     d = randn(n),               # many values                 --> unchanged
     e = rand(collect(1:n), n))  # many values                 --> unchanged
autotype(X, only_changes=true)

# now we could first apply the `discrete_to_continuous` followed by `few_to_finite`
# the first rule will apply on `b` and `e` but the subsequent application of the second
# rule will mean we will get the same result apart for `e` (which will be continuous)

autotype(X, only_changes=true, rules=(:discrete_to_continuous, :few_to_finite))

# Working out which rule to apply will depend on the use case and you may want
# to modify the returned dictionary before using `coerce`. You will typically
# have to take into account what kind of model you will want to use and how to
# either recode or filter the data so that the model gets an appropriate input
# to train on.
