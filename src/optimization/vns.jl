"""
Variable Neighborhood Search (VNS) for warehouse AGV optimization
Focuses on KPI-driven neighborhood structures and shaking mechanisms
"""

using Random, Statistics, Metaheuristics

"""
    VNSSolution

Represents a complete solution for the VNS algorithm
"""
mutable struct VNSSolution
    order_assignments::Dict{Int, Int}      # Order ID -> AGV ID
    agv_routes::Dict{Int, Vector{Int}}     # AGV ID -> Order ID sequence
    kpis::WarehouseKPIs                    # Associated KPI performance
    fitness::Float64                       # Overall fitness score
    is_feasible::Bool                      # Solution feasibility
end

"""
    VNSConfig

Configuration parameters for VNS algorithm
"""
struct VNSConfig
    max_iterations::Int
    max_no_improvement::Int
    shaking_intensity::Vector{Int}
    local_search_method::Symbol
    kpi_weights::Dict{Symbol, Float64}
    acceptance_criteria::Symbol
end

"""
    create_default_vns_config()

Create default VNS configuration for warehouse optimization
"""
function create_default_vns_config()
    return VNSConfig(
        100,                    # max_iterations
        20,                     # max_no_improvement
        [1, 2, 3, 5, 7, 10],   # shaking_intensity
        :hill_climbing,         # local_search_method
        Dict(
            :idle_time => 0.30,
            :utilization => 0.40,
            :on_time_delivery => 0.30
        ),
        :first_improvement      # acceptance_criteria
    )
end

"""
    generate_initial_solution(state::SimulationState)

Generate initial feasible solution using greedy assignment
"""
function generate_initial_solution(state::SimulationState)
    agvs = state.agvs
    orders = copy(state.orders)
    
    # Sort orders by priority and deadline
    filter!(order -> order.status in [:pending, :in_progress], orders)
    sort!(orders, by=order -> (
        order.priority == :urgent ? 1 :
        order.priority == :normal ? 2 : 3,
        order.deadline
    ))
    
    order_assignments = Dict{Int, Int}()
    agv_routes = Dict{Int, Vector{Int}}()
    
    # Initialize routes for each AGV
    for agv in agvs
        agv_routes[agv.id] = Int[]
    end
    
    # Greedy assignment
    for order in orders
        best_agv_id = find_best_agv_for_order(agvs, order, order_assignments)
        if best_agv_id !== nothing
            order_assignments[order.id] = best_agv_id
            push!(agv_routes[best_agv_id], order.id)
        end
    end
    
    # Calculate initial KPIs
    simulated_state = simulate_solution(state, order_assignments, agv_routes)
    initial_kpis = calculate_warehouse_kpis(
        simulated_state.agvs, simulated_state.orders, 
        simulated_state.current_time, state.kpi_history
    )
    
    fitness, _ = calculate_kpi_score(initial_kpis, create_default_vns_config().kpi_weights)
    
    return VNSSolution(
        order_assignments,
        agv_routes,
        initial_kpis,
        fitness,
        true
    )
end

"""
    find_best_agv_for_order(agvs::Vector{AGV}, order::Order, current_assignments::Dict{Int, Int})

Find best AGV for order considering current load and distance
"""
function find_best_agv_for_order(agvs::Vector{AGV}, order::Order, current_assignments::Dict{Int, Int})
    best_agv_id = nothing
    best_score = -Inf
    
    for agv in agvs
        if !can_assign_order(agv, order)
            continue
        end
        
        # Calculate current AGV load
        current_load = length(filter(id -> current_assignments[id] == agv.id, keys(current_assignments)))
        
        # Distance score
        distance = calculate_distance(
            (Int(agv.position[1]), Int(agv.position[2])),
            order.pickup_location
        )
        distance_score = 1.0 / (1.0 + distance / 10.0)
        
        # Load balance score (prefer less loaded AGVs)
        load_score = 1.0 / (1.0 + current_load / 5.0)
        
        # Urgency bonus
        urgency_bonus = order.priority == :urgent ? 0.5 : 0.0
        
        total_score = distance_score * 0.4 + load_score * 0.4 + urgency_bonus * 0.2
        
        if total_score > best_score
            best_score = total_score
            best_agv_id = agv.id
        end
    end
    
    return best_agv_id
end

"""
    simulate_solution(state::SimulationState, assignments::Dict{Int, Int}, routes::Dict{Int, Vector{Int}})

Simulate a specific solution to evaluate its performance
"""
function simulate_solution(state::SimulationState, assignments::Dict{Int, Int}, routes::Dict{Int, Vector{Int}})
    # Create deep copy of state
    sim_state = SimulationState(
        state.warehouse,
        deepcopy(state.agvs),
        deepcopy(state.orders),
        Order[],
        0.0,
        state.current_shift,
        state.current_hour,
        state.order_generator,
        state.kpi_history,
        state.target_kpis,
        state.simulation_speed,
        false,
        zeros(Bool, size(state.collision_matrix)...)
    )
    
    # Apply assignments
    for (order_id, agv_id) in assignments
        order = find_order_by_id(sim_state.orders, order_id)
        agv = find_agv_by_id(sim_state.agvs, agv_id)
        
        if order !== nothing && agv !== nothing
            assign_order!(agv, order)
        end
    end
    
    # Run simulation for limited time to evaluate
    step_simulation!(sim_state, 30.0)  # 30 minutes evaluation
    
    return sim_state
end

"""
    find_order_by_id(orders::Vector{Order}, order_id::Int)

Find order by ID in vector
"""
function find_order_by_id(orders::Vector{Order}, order_id::Int)
    for order in orders
        if order.id == order_id
            return order
        end
    end
    return nothing
end

"""
    find_agv_by_id(agvs::Vector{AGV}, agv_id::Int)

Find AGV by ID in vector
"""
function find_agv_by_id(agvs::Vector{AGV}, agv_id::Int)
    for agv in agvs
        if agv.id == agv_id
            return agv
        end
    end
    return nothing
end

"""
    neighborhood_swap(solution::VNSSolution, k::Int, state::SimulationState)

Swap neighborhood: swap k orders between different AGVs
"""
function neighborhood_swap(solution::VNSSolution, k::Int, state::SimulationState)
    new_assignments = copy(solution.order_assignments)
    new_routes = deepcopy(solution.agv_routes)
    
    # Select k orders to swap
    order_ids = collect(keys(new_assignments))
    if length(order_ids) < 2
        return solution
    end
    
    selected_orders = rand(order_ids, min(k, length(order_ids)))
    
    for order_id in selected_orders
        current_agv_id = new_assignments[order_id]
        
        # Find different AGV to assign to
        available_agvs = [agv.id for agv in state.agvs if agv.id != current_agv_id]
        if !isempty(available_agvs)
            new_agv_id = rand(available_agvs)
            
            # Remove from old AGV route
            filter!(id -> id != order_id, new_routes[current_agv_id])
            
            # Add to new AGV route
            push!(new_routes[new_agv_id], order_id)
            new_assignments[order_id] = new_agv_id
        end
    end
    
    # Evaluate new solution
    sim_state = simulate_solution(state, new_assignments, new_routes)
    new_kpis = calculate_warehouse_kpis(
        sim_state.agvs, sim_state.orders, 
        sim_state.current_time, state.kpi_history
    )
    fitness, _ = calculate_kpi_score(new_kpis, create_default_vns_config().kpi_weights)
    
    return VNSSolution(
        new_assignments,
        new_routes,
        new_kpis,
        fitness,
        true
    )
end

"""
    neighborhood_insert(solution::VNSSolution, k::Int, state::SimulationState)

Insert neighborhood: remove k orders and reinsert them optimally
"""
function neighborhood_insert(solution::VNSSolution, k::Int, state::SimulationState)
    new_assignments = copy(solution.order_assignments)
    new_routes = deepcopy(solution.agv_routes)
    
    # Select k orders to reinsert
    order_ids = collect(keys(new_assignments))
    if isempty(order_ids)
        return solution
    end
    
    selected_orders = rand(order_ids, min(k, length(order_ids)))
    
    # Remove selected orders from current assignments
    for order_id in selected_orders
        old_agv_id = new_assignments[order_id]
        filter!(id -> id != order_id, new_routes[old_agv_id])
        delete!(new_assignments, order_id)
    end
    
    # Reinsert orders optimally
    for order_id in selected_orders
        order = find_order_by_id(state.orders, order_id)
        if order === nothing
            continue
        end
        
        best_agv_id = find_best_agv_for_order(state.agvs, order, new_assignments)
        if best_agv_id !== nothing
            new_assignments[order_id] = best_agv_id
            push!(new_routes[best_agv_id], order_id)
        end
    end
    
    # Evaluate new solution
    sim_state = simulate_solution(state, new_assignments, new_routes)
    new_kpis = calculate_warehouse_kpis(
        sim_state.agvs, sim_state.orders, 
        sim_state.current_time, state.kpi_history
    )
    fitness, _ = calculate_kpi_score(new_kpis, create_default_vns_config().kpi_weights)
    
    return VNSSolution(
        new_assignments,
        new_routes,
        new_kpis,
        fitness,
        true
    )
end

"""
    neighborhood_2opt(solution::VNSSolution, agv_id::Int, state::SimulationState)

2-opt neighborhood: optimize route within single AGV
"""
function neighborhood_2opt(solution::VNSSolution, agv_id::Int, state::SimulationState)
    if !haskey(solution.agv_routes, agv_id) || length(solution.agv_routes[agv_id]) < 2
        return solution
    end
    
    new_routes = deepcopy(solution.agv_routes)
    route = new_routes[agv_id]
    
    # Select two positions to reverse
    i, j = rand(1:length(route)), rand(1:length(route))
    if i > j
        i, j = j, i
    end
    
    # Reverse segment
    route[i:j] = reverse(route[i:j])
    
    # Evaluate new solution
    sim_state = simulate_solution(state, solution.order_assignments, new_routes)
    new_kpis = calculate_warehouse_kpis(
        sim_state.agvs, sim_state.orders, 
        sim_state.current_time, state.kpi_history
    )
    fitness, _ = calculate_kpi_score(new_kpis, create_default_vns_config().kpi_weights)
    
    return VNSSolution(
        solution.order_assignments,
        new_routes,
        new_kpis,
        fitness,
        true
    )
end

"""
    local_search!(solution::VNSSolution, state::SimulationState, config::VNSConfig)

Apply local search to improve current solution
"""
function local_search!(solution::VNSSolution, state::SimulationState, config::VNSConfig)
    improved = true
    iterations = 0
    
    while improved && iterations < 10
        improved = false
        iterations += 1
        
        # Try different neighborhood operators
        for k in 1:3  # Try small neighborhoods first
            # Swap neighborhood
            new_solution = neighborhood_swap(solution, k, state)
            if new_solution.fitness > solution.fitness
                solution = new_solution
                improved = true
            end
            
            # Insert neighborhood
            new_solution = neighborhood_insert(solution, k, state)
            if new_solution.fitness > solution.fitness
                solution = new_solution
                improved = true
            end
        end
        
        # Try 2-opt on each AGV route
        for agv in state.agvs
            new_solution = neighborhood_2opt(solution, agv.id, state)
            if new_solution.fitness > solution.fitness
                solution = new_solution
                improved = true
            end
        end
    end
    
    return solution
end

"""
    shaking!(solution::VNSSolution, k::Int, state::SimulationState)

Apply shaking with intensity k to escape local optima
"""
function shaking!(solution::VNSSolution, k::Int, state::SimulationState)
    shake_type = rand(1:3)
    
    if shake_type == 1
        # Random shaking with swaps
        return neighborhood_swap(solution, k, state)
    elseif shake_type == 2
        # Random shaking with reinsertions
        return neighborhood_insert(solution, k, state)
    else
        # Random shaking with 2-opt
        agv_id = rand([agv.id for agv in state.agvs])
        return neighborhood_2opt(solution, agv_id, state)
    end
end

"""
    vns_optimize(state::SimulationState, config::VNSConfig = create_default_vns_config())

Main VNS optimization function
"""
function vns_optimize(state::SimulationState, config::VNSConfig = create_default_vns_config())
    # Generate initial solution
    current_solution = generate_initial_solution(state)
    best_solution = deepcopy(current_solution)
    
    println("Initial solution fitness: $(current_solution.fitness)")
    println("Initial KPIs - Idle: $(round(current_solution.kpis.agv_idle_time * 100, digits=1))%, Utilization: $(round(current_solution.kpis.utilization_rate * 100, digits=1))%, On-time: $(round(current_solution.kpis.on_time_delivery * 100, digits=1))%")
    
    no_improvement_count = 0
    
    for iteration in 1:config.max_iterations
        k = 1
        
        while k <= length(config.shaking_intensity)
            # Shaking
            shaken_solution = shaking!(current_solution, config.shaking_intensity[k], state)
            
            # Local search
            local_optimal = local_search!(shaken_solution, state, config)
            
            # Acceptance criterion
            if local_optimal.fitness > current_solution.fitness
                current_solution = local_optimal
                
                if current_solution.fitness > best_solution.fitness
                    best_solution = deepcopy(current_solution)
                    println("Iteration $iteration: New best fitness $(best_solution.fitness)")
                    println("KPIs - Idle: $(round(best_solution.kpis.agv_idle_time * 100, digits=1))%, Utilization: $(round(best_solution.kpis.utilization_rate * 100, digits=1))%, On-time: $(round(best_solution.kpis.on_time_delivery * 100, digits=1))%")
                end
                
                k = 1  # Restart with smallest neighborhood
                no_improvement_count = 0
            else
                k += 1
            end
        end
        
        no_improvement_count += 1
        
        # Check stopping criteria
        if no_improvement_count >= config.max_no_improvement
            println("No improvement for $no_improvement_count iterations, stopping...")
            break
        end
    end
    
    println("VNS completed. Best fitness: $(best_solution.fitness)")
    
    return best_solution
end

"""
    apply_solution_to_simulation!(state::SimulationState, solution::VNSSolution)

Apply optimized solution to simulation state
"""
function apply_solution_to_simulation!(state::SimulationState, solution::VNSSolution)
    # Clear current assignments
    for agv in state.agvs
        agv.current_task = nothing
        agv.target_position = nothing
        agv.state = IDLE
    end
    
    for order in state.orders
        order.status = :pending
        order.assigned_agv = nothing
    end
    
    state.pending_orders = copy(state.orders)
    
    # Apply new assignments
    for (order_id, agv_id) in solution.order_assignments
        order = find_order_by_id(state.orders, order_id)
        agv = find_agv_by_id(state.agvs, agv_id)
        
        if order !== nothing && agv !== nothing
            assign_order!(agv, order)
        end
    end
end