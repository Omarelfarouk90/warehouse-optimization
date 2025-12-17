"""
24/7 warehouse simulation engine with 2-shift scheduling and AGV coordination
Handles real-time simulation with dynamic order assignment and KPI tracking
"""

using Random, DataFrames, Statistics

"""
    SimulationState

Current state of the warehouse simulation
"""
mutable struct SimulationState
    warehouse::Warehouse
    agvs::Vector{AGV}
    orders::Vector{Order}
    pending_orders::Vector{Order}      # Orders waiting for assignment
    current_time::Float64              # Simulation time in minutes
    current_shift::Int                 # 1 or 2
    current_hour::Int                  # Hour within current shift (1-12)
    order_generator::OrderGenerator
    kpi_history::KPIHistory
    target_kpis::WarehouseKPIs
    simulation_speed::Float64           # Real-time multiplier
    paused::Bool
    collision_matrix::Matrix{Bool}      # Grid collision tracking
end

"""
    create_simulation_state(num_agvs::Int = 5, seed::Int = 1234)

Initialize simulation state with warehouse, AGVs, and order generator
"""
function create_simulation_state(num_agvs::Int = 5, seed::Int = 1234)
    Random.seed!(seed)
    
    warehouse = create_warehouse()
    agvs = initialize_agvs(num_agvs)
    order_generator = create_order_generator(seed)
    kpi_history = create_kpi_history()
    target_kpis = create_target_kpis()
    
    # Initialize collision matrix
    collision_matrix = zeros(Bool, warehouse.grid_size[1], warehouse.grid_size[2])
    
    return SimulationState(
        warehouse,
        agvs,
        Order[],
        Order[],
        0.0,
        1,
        1,
        order_generator,
        kpi_history,
        target_kpis,
        1.0,  # Real-time simulation
        false,
        collision_matrix
    )
end

"""
    update_shift_timing(state::SimulationState)

Update shift timing and handle shift transitions
"""
function update_shift_timing!(state::SimulationState)
    hours_from_start = state.current_time / 60
    
    # Calculate current shift and hour
    total_shifts_elapsed = Int(floor(hours_from_start / 12))
    state.current_shift = (total_shifts_elapsed % 2) + 1
    state.current_hour = Int(floor(hours_from_start % 12)) + 1
    
    # Handle shift transition (every 12 hours)
    minutes_into_hour = state.current_time % 60
    if minutes_into_hour < SHIFT_HANDOFF_MINUTES && 
       state.current_hour == 1 && 
       (state.current_time - SHIFT_HANDOFF_MINUTES) % 720 < 60
        
        # Shift handoff period
        handle_shift_transition!(state)
    end
end

"""
    handle_shift_transition!(state::SimulationState)

Manage AGV handoff and maintenance during shift changes
"""
function handle_shift_transition!(state::SimulationState)
    for agv in state.agvs
        # Check if AGV needs maintenance during shift change
        if agv.work_time_remaining < 60  # Less than 1 hour remaining
            agv.state = CHARGING
            agv.target_position = agv.position
            
            # Reassign any pending tasks
            if agv.current_task !== nothing
                agv.current_task.status = :pending
                agv.current_task.assigned_agv = nothing
                push!(state.pending_orders, agv.current_task)
                agv.current_task = nothing
            end
        end
    end
end

"""
    generate_new_orders!(state::SimulationState, time_delta::Float64)

Generate new orders based on current demand patterns
"""
function generate_new_orders!(state::SimulationState, time_delta::Float64)
    new_orders = generate_orders_for_time_period(
        state.order_generator,
        state.warehouse,
        time_delta,
        state.current_time
    )
    
    for order in new_orders
        push!(state.orders, order)
        push!(state.pending_orders, order)
    end
end

"""
    assign_orders_to_agvs!(state::SimulationState)

Assign pending orders to available AGVs using priority-based assignment
"""
function assign_orders_to_agvs!(state::SimulationState)
    # Sort pending orders by priority and deadline
    sort!(state.pending_orders, by=order -> (
        order.priority == :urgent ? 1 :
        order.priority == :normal ? 2 : 3,
        order.deadline
    ))
    
    orders_to_remove = Int[]
    
    for (order_idx, order) in enumerate(state.pending_orders)
        # Find suitable AGV
        best_agv = nothing
        best_score = -Inf
        
        for agv in state.agvs
            if can_assign_order(agv, order)
                # Calculate assignment score
                distance = calculate_distance(
                    (Int(agv.position[1]), Int(agv.position[2])),
                    order.pickup_location
                )
                
                # Score based on distance, AGV utilization, and order urgency
                utilization_bonus = (1.0 - get_agv_utilization_rate(agv, state.current_time)) * 0.3
                urgency_bonus = order.priority == :urgent ? 0.5 : 0.0
                distance_penalty = distance / 100.0  # Normalize distance
                
                score = urgency_bonus + utilization_bonus - distance_penalty
                
                if score > best_score
                    best_score = score
                    best_agv = agv
                end
            end
        end
        
        if best_agv !== nothing
            assign_order!(best_agv, order)
            push!(orders_to_remove, order_idx)
        end
    end
    
    # Remove assigned orders from pending list
    for idx in reverse(orders_to_remove)
        deleteat!(state.pending_orders, idx)
    end
end

"""
    update_collision_matrix!(state::SimulationState)

Update collision avoidance matrix for all AGVs
"""
function update_collision_matrix!(state::SimulationState)
    # Reset collision matrix
    fill!(state.collision_matrix, false)
    
    # Mark AGV positions and safety zones
    for agv in state.agvs
        grid_x = Int(round(agv.position[1] / GRID_RESOLUTION))
        grid_y = Int(round(agv.position[2] / GRID_RESOLUTION))
        
        # Mark AGV position and safety zone
        for dx in -SAFETY_DISTANCE:SAFETY_DISTANCE
            for dy in -SAFETY_DISTANCE:SAFETY_DISTANCE
                x, y = grid_x + dx, grid_y + dy
                if 1 <= x <= size(state.collision_matrix, 1) && 
                   1 <= y <= size(state.collision_matrix, 2)
                    state.collision_matrix[x, y] = true
                end
            end
        end
    end
end

"""
    check_and_resolve_collisions!(state::SimulationState)

Check for AGV collisions and resolve with priority-based routing
"""
function check_and_resolve_collisions!(state::SimulationState)
    for i in 1:length(state.agvs)
        for j in i+1:length(state.agvs)
            agv1, agv2 = state.agvs[i], state.agvs[j]
            
            if check_collision(agv1, agv2, SAFETY_DISTANCE * GRID_RESOLUTION)
                # Resolve collision: lower priority AGV yields
                if agv1.current_task !== nothing && agv2.current_task !== nothing
                    if agv1.current_task.priority == :urgent && agv2.current_task.priority != :urgent
                        # AGV2 yields
                        agv2.state = IDLE
                        agv2.target_position = agv2.position
                    elseif agv2.current_task.priority == :urgent && agv1.current_task.priority != :urgent
                        # AGV1 yields
                        agv1.state = IDLE
                        agv1.target_position = agv1.position
                    else
                        # Both same priority, higher ID yields
                        if agv1.id > agv2.id
                            agv1.state = IDLE
                            agv1.target_position = agv1.position
                        else
                            agv2.state = IDLE
                            agv2.target_position = agv2.position
                        end
                    end
                end
            end
        end
    end
end

"""
    update_agv_tasks!(state::SimulationState)

Update AGV task progress and handle order completion
"""
function update_agv_tasks!(state::SimulationState)
    for agv in state.agvs
        if agv.current_task === nothing
            continue
        end
        
        order = agv.current_task
        
        if agv.state == LOADING
            # Simulate loading process
            agv.current_load += order.total_weight
            agv.crate_count += order.total_crates
            order.status = :in_progress
            agv.target_position = OUTPUT_DOCK_POS
            agv.state = MOVING
            
        elseif agv.state == UNLOADING
            # Complete order
            agv.current_load = 0.0
            agv.crate_count = 0
            agv.tasks_completed += 1
            
            order.status = state.current_time <= order.deadline ? :completed : :late
            order.completion_time = state.current_time
            
            agv.current_task = nothing
            agv.state = IDLE
        end
    end
end

"""
    step_simulation!(state::SimulationState, time_delta::Float64 = 1.0)

Advance simulation by time_delta minutes
"""
function step_simulation!(state::SimulationState, time_delta::Float64 = 1.0)
    if state.paused
        return
    end
    
    # Update timing
    old_time = state.current_time
    state.current_time += time_delta * state.simulation_speed
    update_shift_timing!(state)
    
    # Generate new orders
    generate_new_orders!(state, time_delta)
    
    # Assign orders to AGVs
    assign_orders_to_agvs!(state)
    
    # Update AGV positions and states
    for agv in state.agvs
        update_agv_position!(agv, time_delta * state.simulation_speed)
    end
    
    # Update collision detection and resolution
    update_collision_matrix!(state)
    check_and_resolve_collisions!(state)
    
    # Update task progress
    update_agv_tasks!(state)
    
    # Calculate KPIs
    kpis = calculate_warehouse_kpis(state.agvs, state.orders, state.current_time, state.kpi_history)
    
    return kpis
end

"""
    run_simulation(state::SimulationState, duration_minutes::Float64, 
                   step_callback::Union{Function, Nothing} = nothing)

Run simulation for specified duration with optional callback
"""
function run_simulation(state::SimulationState, duration_minutes::Float64, 
                       step_callback::Union{Function, Nothing} = nothing)
    start_time = state.current_time
    end_time = start_time + duration_minutes
    
    kpis_results = WarehouseKPIs[]
    
    while state.current_time < end_time
        kpis = step_simulation!(state, 1.0)  # 1-minute steps
        push!(kpis_results, kpis)
        
        if step_callback !== nothing
            step_callback(state, kpis)
        end
    end
    
    return kpis_results
end

"""
    reset_simulation!(state::SimulationState)

Reset simulation to initial state
"""
function reset_simulation!(state::SimulationState)
    state.orders = Order[]
    state.pending_orders = Order[]
    state.current_time = 0.0
    state.current_shift = 1
    state.current_hour = 1
    
    # Reset AGVs
    for agv in state.agvs
        agv.position = (1.0 + (agv.id-1) * 2.0, WAREHOUSE_HEIGHT / 2)
        agv.current_load = 0.0
        agv.crate_count = 0
        agv.state = IDLE
        agv.target_position = nothing
        agv.current_task = nothing
        agv.work_time_remaining = MAX_WORK_TIME_MINUTES
        agv.total_distance_traveled = 0.0
        agv.idle_time = 0.0
        agv.tasks_completed = 0
        agv.last_update_time = 0.0
    end
    
    # Reset KPI history
    state.kpi_history = create_kpi_history()
end

"""
    get_simulation_summary(state::SimulationState, kpis_results::Vector{WarehouseKPIs})

Generate simulation performance summary
"""
function get_simulation_summary(state::SimulationState, kpis_results::Vector{WarehouseKPIs})
    if isempty(kpis_results)
        return "No simulation data available."
    end
    
    final_kpis = kpis_results[end]
    
    # Calculate trends
    trends = detect_kpi_trends(state.kpi_history)
    
    summary = """
    ===== SIMULATION SUMMARY =====
    Duration: $(round(state.current_time / 60, digits=1)) hours
    Total Orders Generated: $(length(state.orders))
    
    Final KPI Performance:
    - AGV Idle Time: $(round(final_kpis.agv_idle_time * 100, digits=1))% (Target: $(round(state.target_kpis.agv_idle_time * 100, digits=1))%)
    - AGV Utilization: $(round(final_kpis.utilization_rate * 100, digits=1))% (Target: $(round(state.target_kpis.utilization_rate * 100, digits=1))%)
    - On-Time Delivery: $(round(final_kpis.on_time_delivery * 100, digits=1))% (Target: $(round(state.target_kpis.on_time_delivery * 100, digits=1))%)
    
    Performance Trends:
    - Idle Time: $(trends[:idle_trend])
    - Utilization: $(trends[:utilization_trend])
    - On-Time Delivery: $(trends[:delivery_trend])
    
    AGV Performance:
    """
    
    for agv in state.agvs
        summary *= """
        AGV $(agv.id):
        - Tasks Completed: $(agv.tasks_completed)
        - Distance Traveled: $(round(agv.total_distance_traveled, digits=1)) meters
        - Current State: $(agv.state)
        """
    end
    
    return summary
end