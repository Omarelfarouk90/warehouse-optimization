module WarehouseOptimization

using JuMP, CPLEX, Makie, GLMakie, DataFrames, StatsBase, Metaheuristics, Distributions, LinearAlgebra, Random

# Core modules
include("src/core/warehouse.jl")
include("src/core/agv.jl")
include("src/core/simulation.jl")
include("src/core/kpis.jl")

# Optimization modules
include("src/optimization/vns.jl")
include("src/optimization/lns.jl")
include("src/optimization/hybrid.jl")

# Visualization modules
include("src/visualization/animation.jl")
include("src/visualization/dashboard.jl")

# Planning modules
include("src/planning/scenarios.jl")
include("src/planning/analysis.jl")

# Data configurations
include("data/warehouse_layout.jl")
include("data/demand_patterns.jl")

# Export main functions and types
export Warehouse, AGV, Order, SimulationState, WarehouseKPIs
export create_warehouse, initialize_agvs, generate_orders
export run_simulation, calculate_kpis
export vns_optimize, lns_optimize, hybrid_optimize
export animate_warehouse, create_dashboard
export generate_scenario, analyze_performance

end