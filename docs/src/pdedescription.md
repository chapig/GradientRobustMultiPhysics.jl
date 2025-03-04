
# PDE Description

## Purpose

Although a more manually low-level assembly of your problem is possible, it is advised to describe it in the form of a PDEDescription
to get access to certain automated mechanisms (in particular concerning fixpoint solvers).

The PDEDescription has similarities with the weak form of your problem (without time derivatives that are added separately by TimeControlSolver) and in general does not need any information on the discretisation at this point.

The following flow chart summarises the assemble process that is run during the solve process. The green parts can be modified/specified by the user, the rest is handled automatically. For details on steering the solver see [PDE Solvers](@ref)

![Assembly Flowchart](assembly_flowchart.png) 


```@docs
PDEDescription
Base.show(io::IO, PDE::PDEDescription)
```


## Creating/Extending a PDEDescription

Several add...! functions allow to extend the problems at any stage. There are several prototype PDEs documented on the [PDE Prototypes](@ref) page that can be used as a point of departure. Below is a list of functions that allows to initialise and extend a PDEDescription.

```@autodocs
Modules = [GradientRobustMultiPhysics]
Pages = ["pdedescription.jl"]
Order   = [:type, :function]
```

## PDE Operators

The PDE consists of PDEOperators characterising some feature of the model (like friction, convection, exterior forces etc.), they describe the continuous weak form of the PDE. 


```@docs
GradientRobustMultiPhysics.PDEOperator
```

The following table lists all available operators and physics-motivated constructors for them. Click on them or scroll down to find out more details.

| Main constructors                   | Special constructors                     | Mathematically                                                                                                 |
| :---------------------------------- | :--------------------------------------- | :------------------------------------------------------------------------------------------------------------- |
| [`AbstractBilinearForm`](@ref)      |                                          | ``(\mathrm{A}(\mathrm{FO}_1(u)),\mathrm{FO}_2(v))`` or ``(\mathrm{FO}_1(u),\mathrm{A}(\mathrm{FO}_2(v)))``     |
|                                     | [`LaplaceOperator`](@ref)                | ``(\kappa \nabla u,\nabla v)``                                                                                 |
|                                     | [`ReactionOperator`](@ref)               | ``(\alpha u, v)``                                                                                              |
|                                     | [`LagrangeMultiplier`](@ref)             | ``(\mathrm{FO}_1(u), v)`` (automatically assembles 2nd transposed block)                                       |
|                                     | [`ConvectionOperator`](@ref)             | ``(\beta \cdot \nabla u, v)`` (beta is function)                                                               |
|                                     | [`HookStiffnessOperator2D`](@ref)        | ``(\mathbb{C} \epsilon(u),\epsilon(v))`` (also 1D or 3D variants exist)                                        |
| [`AbstractTrilinearForm`](@ref)     |                                          | ``(\mathrm{A}(\mathrm{FO}_1(a),\mathrm{FO}_2(u)),\mathrm{FO}_3(v))``                                           |
|                                     | [`ConvectionOperator`](@ref)             | ``((a \cdot \nabla) u, v)`` (a is registered unknown)                                                          |
|                                     | [`ConvectionRotationFormOperator`](@ref) | ``((a \times \nabla) u,v)`` (a is registered unknown, only 2D for now)                                         |
| [`GenerateNonlinearForm`](@ref)     |                                          | ``(\mathrm{NA}(\mathrm{FO}_1(u),...,\mathrm{FO}_{N-1}(u)),\mathrm{FO}_N(v))``                                  |
| [`RhsOperator`](@ref)               |                                          | ``(f \cdot \mathrm{FO}(v))``                                                                                   |

Legend: ``\mathrm{FO}``  are placeholders for [Function Operators](@ref), and ``\mathrm{A}`` stands for a (linear) [Actions](@ref) (that only expects the operator value of the finite element function as an input) and ``\mathrm{NA}`` stands for a (nonlinear) [Actions](@ref) (see [`GenerateNonlinearForm`](@ref) for details).


### Common Operators

Below you find the special constructors of available common linear, bilinear and trilinear forms.

```@docs
AbstractBilinearForm
AbstractTrilinearForm
LaplaceOperator
ReactionOperator
ConvectionOperator
ConvectionRotationFormOperator
HookStiffnessOperator1D
HookStiffnessOperator2D
HookStiffnessOperator3D
RhsOperator
```

### Lagrange Multipliers

There is a special bilinearform intended to use for the assembly of Lagrange multipliers that automatically copies itself to the transposed block of the PDEdescription.

```@docs
LagrangeMultiplier
```

### Nonlinear Operators

Nonlinear Operators can be setup in two ways. The manual way requires the user to define an action with a nonlinear action kernel (see [Action Kernels](@ref)) that specifies the linearisation of the nonlinearity. The is also an automatic way where the user specifies a norml action kernel (where the input can be used nonlinearly) which is then automatically differentiated to generate the linearised action kernel, see below for details.

```@docs
GenerateNonlinearForm
```


## Other Operators

There are some more operators that do not fit into the structures above. Also, in the future, the goal is to open up the operator level for exterior code to setup operators that are assembled elsewhere.

```@docs
FVConvectionDiffusionOperator
DiagonalOperator
CopyOperator
```


## Global Constraints

GlobalConstraints are additional constraints that the user does not wish to implement as a global Lagrange multiplier because it e.g. causes a dense row in the system matrix and therefore may destroy the performance of the sparse matrix routines. Such a constraint may be a fixed integral mean. Another application are periodic boundary conditions or glued-together quantities in different regions of the grid. Here a CombineDofs constraint may help.

```@autodocs
Modules = [GradientRobustMultiPhysics]
Pages = ["globalconstraints.jl"]
Order   = [:type, :function]
```

```@docs
add_constraint!
```


## Dirichlet Boundary Data

BoundaryOperators carry the boundary data for each unknown. Each regions can have a different AbstractBoundaryType and an associated data function that satisfies the interface function data!(result,x::Array{<:Real,1}) or function data!(result,x::Array{<:Real,1},t::Real) if it is also time-dependent.


| AbstractBoundaryType                | Subtypes                                 | causes                                                                  |
| :---------------------------------- | :--------------------------------------- | :---------------------------------------------------------------------- |
| [`DirichletBoundary`](@ref)         |                                          |                                                                         |
|                                     | [`BestapproxDirichletBoundary`](@ref)    | computation of Dirichlet data by bestapproximation along boundary faces |
|                                     | [`InterpolateDirichletBoundary`](@ref)   | computation of Dirichlet data by interpolation along boundary faces     |
|                                     | [`HomogeneousDirichletBoundary`](@ref)   | zero Dirichlet data on all dofs                                         |


```@docs
BoundaryOperator
add_boundarydata!
```

## Other Boundary Data

NeumannBoundary can be implemented as a RhsOperator with AT = ON_BFACES

PeriodicBoundary can be implemented as a CombineDofs <: AbstractGlobalConstraint

SymmetryBoundary can be implemented by penalisation as a AbstractBilinearForm on BFaces and specified boundary regions with operator NormalFlux + MultiplyScalarAction(penalty).
