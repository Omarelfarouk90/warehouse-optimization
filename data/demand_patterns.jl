"""
Demand patterns and order generation for variable order sizes
Optimized for 24/7 operation with 2 shifts per day
"""

using Distributions, Random

# Order size distributions
const SMALL_ORDER_PROB = 0.4    # 1-2 crates
const MEDIUM_ORDER_PROB = 0.35  # 3-4 crates  
const LARGE_ORDER_PROB = 0.25   # 5 crates (max capacity)

# Priority distributions
const URGENT_ORDER_PROB = 0.10  # 10% urgent
const NORMAL_ORDER_PROB = 0.70  # 70% normal
const LOW_ORDER_PROB = 0.20     # 20% low priority

# Item type distributions (ABC classification)
const ITEM_A_PROB = 0.20        # High-demand items (20%)
const ITEM_B_PROB = 0.50        # Medium-demand items (50%)
const ITEM_C_PROB = 0.30        # Low-demand items (30%)

# Demand patterns by shift and time
struct DemandPattern
    shift::Int                          # 1 or 2
    hour::Int                           # Hour of shift (1-12)
    base_rate::Float64                  # Orders per minute
    peak_multiplier::Float64           # Peak hour multiplier
    urgency_multiplier::Float64         # Urgency probability adjustment
end

# Define demand patterns for 24/7 operation
const DEMAND_PATTERNS = [
    # Shift 1 (12 hours) - Higher demand
    DemandPattern(1, 1, 0.03, 1.2, 1.0),    # Hour 1: Start ramp-up
    DemandPattern(1, 2, 0.04, 1.5, 1.1),    # Hour 2: Building
    DemandPattern(1, 3, 0.05, 1.8, 1.2),    # Hour 3: Peak building
    DemandPattern(1, 4, 0.06, 2.0, 1.3),    # Hour 4: Peak
    DemandPattern(1, 5, 0.06, 2.0, 1.3),    # Hour 5: Peak
    DemandPattern(1, 6, 0.05, 1.8, 1.2),    # Hour 6: Peak declining
    DemandPattern(1, 7, 0.04, 1.5, 1.1),    # Hour 7: declining
    DemandPattern(1, 8, 0.04, 1.3, 1.0),    # Hour 8: steady
    DemandPattern(1, 9, 0.03, 1.2, 1.0),    # Hour 9: steady
    DemandPattern(1, 10, 0.03, 1.1, 0.9),   # Hour 10: declining
    DemandPattern(1, 11, 0.02, 1.0, 0.8),   # Hour 11: low
    DemandPattern(1, 12, 0.02, 0.8, 0.7),   # Hour 12: shift end
    
    # Shift 2 (12 hours) - Lower demand, maintenance focus
    DemandPattern(2, 1, 0.02, 0.8, 0.7),    # Hour 1: shift start
    DemandPattern(2, 2, 0.02, 0.9, 0.8),    # Hour 2: building
    DemandPattern(2, 3, 0.03, 1.0, 0.9),    # Hour 3: steady
    DemandPattern(2, 4, 0.03, 1.1, 1.0),    # Hour 4: steady
    DemandPattern(2, 5, 0.03, 1.1, 1.0),    # Hour 5: steady
    DemandPattern(2, 6, 0.02, 1.0, 0.9),    # Hour 6: steady
    DemandPattern(2, 7, 0.02, 0.9, 0.8),    # Hour 7: declining
    DemandPattern(2, 8, 0.02, 0.8, 0.7),    # Hour 8: maintenance window
    DemandPattern(2, 9, 0.01, 0.7, 0.6),    # Hour 9: maintenance
    DemandPattern(2, 10, 0.01, 0.7, 0.6),   # Hour 10: maintenance
    DemandPattern(2, 11, 0.01, 0.6, 0.5),    # Hour 11: low
    DemandPattern(2, 12, 0.01, 0.5, 0.4),   # Hour 12: shift end
]

"""
    OrderGenerator

Generates orders based on demand patterns and probabilities
"""
mutable struct OrderGenerator
    next_order_id::Int
    current_shift::Int
    current_hour::Int
    time_accumulator::Float64
    rng::MersenneTwister
end

"""
    create_order_generator(seed::Int = 1234)

Create initialized order generator
"""
function create_order_generator(seed::Int = 1234)
    return OrderGenerator(1, 1, 1, 0.0, MersenneTwister(seed))
end

"""
    generate_order_size(generator::OrderGenerator)

Generate random order size (number of crates) based on distribution
"""
function generate_order_size(generator::OrderGenerator)
    rand_val = rand(generator.rng)
    
    if rand_val < SMALL_ORDER_PROB
        return rand(generator.rng, 1:2)  # 1-2 crates
    elseif rand_val < SMALL_ORDER_PROB + MEDIUM_ORDER_PROB
        return rand(generator.rng, 3:4)  # 3-4 crates
    else
        return 5  # 5 crates (max)
    end
end

"""
    generate_order_priority(generator::OrderGenerator, urgency_mult::Float64 = 1.0)

Generate order priority with optional urgency multiplier
"""
function generate_order_priority(generator::OrderGenerator, urgency_mult::Float64 = 1.0)
    # Adjust urgency probability
    urgent_prob = URGENT_ORDER_PROB * urgency_mult
    urgent_prob = min(urgent_prob, 0.3)  # Cap at 30%
    
    rand_val = rand(generator.rng)
    
    if rand_val < urgent_prob
        return :urgent
    elseif rand_val < urgent_prob + NORMAL_ORDER_PROB
        return :normal
    else
        return :low
    end
end

"""
    generate_order_items(generator::OrderGenerator, num_crates::Int)

Generate item types for an order based on ABC distribution
"""
function generate_order_items(generator::OrderGenerator, num_crates::Int)
    items = Tuple{Symbol, Int}[]
    
    for _ in 1:num_crates
        rand_val = rand(generator.rng)
        
        if rand_val < ITEM_A_PROB
            item_type = :A
        elseif rand_val < ITEM_A_PROB + ITEM_B_PROB
            item_type = :B
        else
            item_type = :C
        end
        
        # Add to existing items or create new entry
        found = false
        for i in 1:length(items)
            if items[i][1] == item_type
                items[i] = (item_type, items[i][2] + 1)
                found = true
                break
            end
        end
        
        if !found
            push!(items, (item_type, 1))
        end
    end
    
    return items
end

"""
    calculate_order_deadline(priority::Symbol, current_time::Float64)

Calculate order deadline based on priority (minutes from creation)
"""
function calculate_order_deadline(priority::Symbol, current_time::Float64)
    if priority == :urgent
        deadline_minutes = 15.0  # 15 minutes for urgent
    elseif priority == :normal
        deadline_minutes = 30.0  # 30 minutes for normal
    else
        deadline_minutes = 60.0  # 60 minutes for low priority
    end
    
    return current_time + deadline_minutes
end

"""
    generate_single_order(generator::OrderGenerator, warehouse::Warehouse, current_time::Float64)

Generate a single random order
"""
function generate_single_order(generator::OrderGenerator, warehouse::Warehouse, current_time::Float64)
    order_id = generator.next_order_id
    generator.next_order_id += 1
    
    # Generate order size and items
    num_crates = generate_order_size(generator)
    items = generate_order_items(generator, num_crates)
    
    # Calculate total weight
    total_weight = num_crates * CRATE_WEIGHT_KG
    
    # Get current demand pattern
    pattern_idx = (generator.current_shift - 1) * 12 + generator.current_hour
    pattern = DEMAND_PATTERNS[pattern_idx]
    
    # Generate priority
    priority = generate_order_priority(generator, pattern.urgency_multiplier)
    deadline = calculate_order_deadline(priority, current_time)
    
    # Select random storage location based on item types
    primary_item_type = items[1][1]
    storage_loc = find_nearest_storage(warehouse, primary_item_type, total_weight)
    
    if storage_loc === nothing
        # Fallback to any storage location
        storage_loc = rand(generator.rng, warehouse.storage_locations)
    end
    
    order = Order(
        order_id,
        items,
        total_weight,
        num_crates,
        priority,
        current_time,
        deadline,
        storage_loc.position,
        :pending,
        nothing,
        nothing
    )
    
    return order
end

"""
    generate_orders_for_time_period(generator::OrderGenerator, warehouse::Warehouse, 
                                   time_delta::Float64, current_time::Float64)

Generate orders for a specific time period based on demand patterns
"""
function generate_orders_for_time_period(generator::OrderGenerator, warehouse::Warehouse, 
                                       time_delta::Float64, current_time::Float64)
    orders = Order[]
    
    # Get current demand pattern
    pattern_idx = (generator.current_shift - 1) * 12 + generator.current_hour
    pattern = DEMAND_PATTERNS[pattern_idx]
    
    # Calculate expected orders in this time period
    order_rate = pattern.base_rate * pattern.peak_multiplier
    expected_orders = order_rate * time_delta
    
    # Use Poisson distribution for order arrival
    num_orders = rand(generator.rng, Poisson(expected_orders))
    
    for _ in 1:num_orders
        order = generate_single_order(generator, warehouse, current_time)
        push!(orders, order)
    end
    
    return orders
end

"""
    update_time_and_shift(generator::OrderGenerator, time_delta::Float64)

Update generator's time tracking and shift management
"""
function update_time_and_shift(generator::OrderGenerator, time_delta::Float64)
    generator.time_accumulator += time_delta
    
    # Check if we've moved to the next hour
    if generator.time_accumulator >= 60.0  # 60 minutes per hour
        generator.time_accumulator -= 60.0
        generator.current_hour += 1
        
        # Check if we've moved to the next shift
        if generator.current_hour > 12
            generator.current_hour = 1
            generator.current_shift += 1
            
            # Reset to shift 1 after 2 shifts (24 hours)
            if generator.current_shift > 2
                generator.current_shift = 1
            end
        end
    end
end

"""
    create_scenario_orders(scenario_type::Symbol, duration_hours::Int, warehouse::Warehouse)

Generate orders for specific scenarios
"""
function create_scenario_orders(scenario_type::Symbol, duration_hours::Int, warehouse::Warehouse)
    generator = create_order_generator()
    orders = Order[]
    
    if scenario_type == :base
        # Standard operation
        total_minutes = duration_hours * 60
        current_time = 0.0
        
        while current_time < total_minutes
            time_delta = min(5.0, total_minutes - current_time)  # 5-minute chunks
            new_orders = generate_orders_for_time_period(generator, warehouse, time_delta, current_time)
            append!(orders, new_orders)
            update_time_and_shift(generator, time_delta)
            current_time += time_delta
        end
        
    elseif scenario_type == :peak_demand
        # 150% demand scenario
        generator.time_accumulator = 0.0
        
        total_minutes = duration_hours * 60
        current_time = 0.0
        
        while current_time < total_minutes
            time_delta = min(5.0, total_minutes - current_time)
            
            # Modify demand pattern for peak
            for pattern in DEMAND_PATTERNS
                pattern.base_rate *= 1.5
            end
            
            new_orders = generate_orders_for_time_period(generator, warehouse, time_delta, current_time)
            append!(orders, new_orders)
            update_time_and_shift(generator, time_delta)
            current_time += time_delta
        end
        
    elseif scenario_type == :agv_failure
        # Normal demand but with AGV constraints
        generator.time_accumulator = 0.0
        
        total_minutes = duration_hours * 60
        current_time = 0.0
        
        while current_time < total_minutes
            time_delta = min(5.0, total_minutes - current_time)
            new_orders = generate_orders_for_time_period(generator, warehouse, time_delta, current_time)
            append!(orders, new_orders)
            update_time_and_shift(generator, time_delta)
            current_time += time_delta
        end
    end
    
    return orders
end