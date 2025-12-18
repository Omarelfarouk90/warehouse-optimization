"""
AGV (Automated Guided Vehicle) models and behavior for warehouse logistics
"""

# AGV specifications
const AGV_CAPACITY_KG = 20.0      # Maximum load capacity
const AGV_CAPACITY_CRATES = 5     # Maximum number of crates
const AGV_SPEED_M_PER_MIN = 1.0   # Movement speed
const MAX_WORK_TIME_MINUTES = 240  # 4 hours continuous operation
const CHARGING_TIME_MINUTES = 10   # 10 minutes charging cycle

const CRATE_WEIGHT_KG = 4.0       # Average weight per crate

"""
    AGVState

Current state of an AGV
"""
@enum AGVState IDLE MOVING LOADING UNLOADING CHARGING MAINTENANCE

"""
    Order

Represents a customer order to be fulfilled
"""
mutable struct Order
    id::Int
    items::Vector{Tuple{Symbol, Int}}  # (item_type, quantity) pairs
    total_weight::Float64
    total_crates::Int
    priority::Symbol                    # :urgent, :normal, :low
    creation_time::Float64               # When order was created
    deadline::Float64                   # Delivery deadline (minutes)
    pickup_location::Tuple{Int, Int}     # Storage location coordinates
    status::Symbol                       # :pending, :assigned, :in_progress, :completed, :late
    assigned_agv::Union{Int, Nothing}    # AGV ID if assigned
    completion_time::Union{Float64, Nothing}  # When completed
end

"""
    AGV

Individual AGV robot with position, capacity, and state tracking
"""
mutable struct AGV
    id::Int
    position::Tuple{Float64, Float64}  # Real-time position (meters)
    current_load::Float64              # Current load in kg
    crate_count::Int                   # Number of crates
    state::AGVState                    # Current operational state
    target_position::Union{Tuple{Float64, Float64}, Nothing}  # Destination
    current_task::Union{Order, Nothing}  # Assigned task
    work_time_remaining::Float64       # Minutes until charging needed
    total_distance_traveled::Float64   # Total distance (meters)
    idle_time::Float64                 # Total idle time (minutes)
    tasks_completed::Int               # Number of completed tasks
    last_update_time::Float64          # Simulation time of last update
end

"""
    initialize_agvs(num_agvs::Int)

Create initial fleet of AGVs at starting positions
"""
function initialize_agvs(num_agvs::Int = 5)
    agvs = AGV[]
    
    for i in 1:num_agvs
        # Start AGVs at charging stations
        start_x = 1.0 + (i-1) * 2.0  # Spread along the left side
        start_y = WAREHOUSE_HEIGHT / 2
        
        agv = AGV(
            i,
            (start_x, start_y),
            0.0,                    # No initial load
            0,                      # No initial crates
            IDLE,                   # Start idle
            nothing,                # No target position
            nothing,                # No current task
            MAX_WORK_TIME_MINUTES,  # Full work time available
            0.0,                    # No distance traveled
            0.0,                    # No idle time
            0,                      # No tasks completed
            0.0                     # Start at time 0
        )
        
        push!(agvs, agv)
    end
    
    return agvs
end

"""
    can_assign_order(agv::AGV, order::Order)

Check if AGV can handle the given order
"""
function can_assign_order(agv::AGV, order::Order)
    # Check capacity constraints
    if agv.current_load + order.total_weight > AGV_CAPACITY_KG
        return false
    end
    
    if agv.crate_count + order.total_crates > AGV_CAPACITY_CRATES
        return false
    end
    
    # Check AGV state
    if agv.state == CHARGING || agv.state == MAINTENANCE
        return false
    end
    
    # Check work time remaining
    estimated_task_time = estimate_task_completion_time(agv, order)
    if agv.work_time_remaining < estimated_task_time + 10  # 10 min buffer
        return false
    end
    
    return true
end

"""
    assign_order(agv::AGV, order::Order)

Assign an order to an AGV
"""
function assign_order!(agv::AGV, order::Order)
    agv.current_task = order
    agv.target_position = order.pickup_location
    agv.state = MOVING
    order.status = :assigned
    order.assigned_agv = agv.id
end

"""
    update_agv_position!(agv::AGV, time_elapsed::Float64)

Update AGV position based on current state and target using Cartesian movement
"""
function update_agv_position!(agv::AGV, time_elapsed::Float64)
    if agv.state == MOVING && agv.target_position !== nothing
        current_pos = agv.position
        target_pos = agv.target_position
        
        # Calculate Manhattan distance for grid-based movement
        dx = target_pos[1] - current_pos[1]
        dy = target_pos[2] - current_pos[2]
        manhattan_distance = abs(dx) + abs(dy)
        
        if manhattan_distance < 0.1  # Reached target
            agv.position = target_pos
            agv.target_position = nothing
            agv.state = determine_next_state(agv)
        else
            # Move towards target using Cartesian movement (one axis at a time)
            move_distance = AGV_SPEED_M_PER_MIN * time_elapsed
            
            # Prioritize X-axis movement first, then Y-axis
            if abs(dx) > 0.1
                # Move along X-axis
                if move_distance >= abs(dx)
                    # Complete X-axis movement
                    agv.position = (target_pos[1], current_pos[2])
                    agv.total_distance_traveled += abs(dx)
                    move_distance -= abs(dx)
                    
                    # Use remaining distance for Y-axis movement
                    if move_distance > 0 && abs(dy) > 0.1
                        if move_distance >= abs(dy)
                            # Complete Y-axis movement
                            agv.position = target_pos
                            agv.total_distance_traveled += abs(dy)
                            agv.target_position = nothing
                            agv.state = determine_next_state(agv)
                        else
                            # Move partially along Y-axis
                            y_direction = dy > 0 ? 1 : -1
                            agv.position = (target_pos[1], current_pos[2] + y_direction * move_distance)
                            agv.total_distance_traveled += move_distance
                        end
                    end
                else
                    # Move partially along X-axis
                    x_direction = dx > 0 ? 1 : -1
                    agv.position = (current_pos[1] + x_direction * move_distance, current_pos[2])
                    agv.total_distance_traveled += move_distance
                end
            else
                # Only Y-axis movement remaining
                if move_distance >= abs(dy)
                    # Complete Y-axis movement
                    agv.position = target_pos
                    agv.total_distance_traveled += abs(dy)
                    agv.target_position = nothing
                    agv.state = determine_next_state(agv)
                else
                    # Move partially along Y-axis
                    y_direction = dy > 0 ? 1 : -1
                    agv.position = (current_pos[1], current_pos[2] + y_direction * move_distance)
                    agv.total_distance_traveled += move_distance
                end
            end
            
            # Update work time
            agv.work_time_remaining -= time_elapsed
        end
    elseif agv.state == IDLE
        agv.idle_time += time_elapsed
        
        # Check if AGV needs charging
        if agv.work_time_remaining < 30  # 30 min threshold
            agv.state = CHARGING
            agv.target_position = agv.position  # Stay in place for charging
        end
    elseif agv.state == CHARGING
        agv.work_time_remaining += time_elapsed * 24  # Fast charging (1 min real = 24 min work)
        agv.idle_time += time_elapsed
        
        if agv.work_time_remaining >= MAX_WORK_TIME_MINUTES
            agv.state = IDLE
            agv.work_time_remaining = MAX_WORK_TIME_MINUTES
        end
    end
    
    agv.last_update_time += time_elapsed
end

"""
    determine_next_state(agv::AGV)

Determine next AGV state after reaching target
"""
function determine_next_state(agv::AGV)
    if agv.current_task === nothing
        return IDLE
    end
    
    order = agv.current_task
    
    if order.status == :assigned
        return LOADING
    elseif order.status == :in_progress
        return UNLOADING
    else
        return IDLE
    end
end

"""
    estimate_task_completion_time(agv::AGV, order::Order)

Estimate time to complete a task in minutes
"""
function estimate_task_completion_time(agv::AGV, order::Order)
    # Calculate distances
    pickup_dist = calculate_distance(
        (Int(agv.position[1]), Int(agv.position[2])),
        order.pickup_location
    )
    
    output_dist = calculate_distance(
        order.pickup_location,
        OUTPUT_DOCK_POS
    )
    
    # Time calculations (minutes)
    travel_time = (pickup_dist + output_dist) * GRID_RESOLUTION / AGV_SPEED_M_PER_MIN
    loading_time = 2.0 + order.total_crates * 0.5  # 2 min base + 0.5 min per crate
    unloading_time = 1.0 + order.total_crates * 0.3  # 1 min base + 0.3 min per crate
    
    return travel_time + loading_time + unloading_time
end

"""
    get_agv_utilization_rate(agv::AGV, total_time::Float64)

Calculate AGV utilization rate (time spent on tasks vs total time)
"""
function get_agv_utilization_rate(agv::AGV, total_time::Float64)
    if total_time == 0
        return 0.0
    end
    
    task_time = total_time - agv.idle_time
    return task_time / total_time
end

"""
    check_collision(agv1::AGV, agv2::AGV, safety_distance::Float64 = 0.5)

Check if two AGVs are too close (potential collision) using Euclidean distance
"""
function check_collision(agv1::AGV, agv2::AGV, safety_distance::Float64 = 0.5)
    distance = calculate_euclidean_distance(agv1.position, agv2.position)
    return distance < safety_distance
end