"""
Basic example to test the warehouse optimization system
Demonstrates V-shaped warehouse layout, AGV simulation, and KPI tracking
"""

# Load the main module (when running from project root)
include("../main.jl")
using .WarehouseOptimization

function basic_warehouse_example()
    println("=== WAREHOUSE OPTIMIZATION SYSTEM DEMO ===")
    println("V-shaped 10m × 5m warehouse with 5 AGVs")
    println("24/7 operation with 2 shifts")
    println()
    
    # Create warehouse and simulation state
    println("Creating warehouse layout...")
    warehouse = create_warehouse()
    println("Warehouse dimensions: $(warehouse.dimensions) meters")
    println("Storage locations: $(length(warehouse.storage_locations))")
    println("Grid size: $(warehouse.grid_size) cells")
    println()
    
    # Create simulation state
    println("Initializing simulation state...")
    state = create_simulation_state(5, 1234)
    println("AGVs initialized: $(length(state.agvs))")
    println("Simulation time: $(state.current_time) minutes")
    println()
    
    # Display warehouse layout information
    println("=== WAREHOUSE LAYOUT ANALYSIS ===")
    zone_counts = Dict(:high => 0, :medium => 0, :low => 0)
    type_counts = Dict(:A => 0, :B => 0, :C => 0)
    
    for location in warehouse.storage_locations
        zone_counts[location.zone] += 1
        type_counts[location.item_type] += 1
    end
    
    println("Storage zones:")
    for (zone, count) in zone_counts
        println("  $zone frequency: $count locations")
    end
    
    println("Item types:")
    for (item_type, count) in type_counts
        println("  Type $item_type: $count locations")
    end
    
    println()
    println("Input dock position: $(warehouse.input_dock)")
    println("Output dock position: $(warehouse.output_dock)")
    println()
    
    # Generate some initial orders
    println("=== ORDER GENERATION ===")
    println("Generating initial orders...")
    
    # Generate 30 minutes of orders
    initial_orders = generate_orders_for_time_period(
        state.order_generator, warehouse, 30.0, 0.0
    )
    
    println("Generated $(length(initial_orders)) orders in 30 minutes")
    
    if !isempty(initial_orders)
        priority_counts = Dict(:urgent => 0, :normal => 0, :low => 0)
        size_counts = Dict(:small => 0, :medium => 0, :large => 0)
        
        for order in initial_orders
            priority_counts[order.priority] += 1
            size_category = order.total_crates <= 2 ? :small : 
                           order.total_crates <= 4 ? :medium : :large
            size_counts[size_category] += 1
        end
        
        println("Order priorities:")
        for (priority, count) in priority_counts
            println("  $priority: $count orders")
        end
        
        println("Order sizes:")
        for (size, count) in size_counts
            println("  $size: $count orders")
        end
        
        # Show sample order
        sample_order = initial_orders[1]
        println("\nSample order details:")
        println("  ID: $(sample_order.id)")
        println("  Items: $(sample_order.items)")
        println("  Weight: $(sample_order.total_weight) kg")
        println("  Crates: $(sample_order.total_crates)")
        println("  Priority: $(sample_order.priority)")
        println("  Deadline: $(sample_order.deadline) minutes")
        println("  Pickup location: $(sample_order.pickup_location)")
    end
    
    println()
    
    # Run initial simulation
    println("=== BASIC SIMULATION ===")
    println("Running 60 minutes of simulation...")
    
    # Add generated orders to simulation
    for order in initial_orders
        push!(state.orders, order)
        push!(state.pending_orders, order)
    end
    
    # Run simulation for 60 minutes
    kpis_results = run_simulation(state, 60.0)
    
    println("Simulation completed!")
    
    # Display results
    final_kpis = kpis_results[end]
    println()
    println("=== SIMULATION RESULTS ===")
    println("Total simulation time: $(round(final_kpis.total_simulation_time / 60, digits=1)) hours")
    println("Total orders processed: $(final_kpis.total_orders)")
    println("Completed orders: $(final_kpis.completed_orders)")
    println("Late orders: $(final_kpis.late_orders)")
    println()
    
    println("Primary KPIs:")
    println("  AGV Idle Time: $(round(final_kpis.agv_idle_time * 100, digits=1))% (Target: $(round(state.target_kpis.agv_idle_time * 100, digits=1))%)")
    println("  AGV Utilization: $(round(final_kpis.utilization_rate * 100, digits=1))% (Target: $(round(state.target_kpis.utilization_rate * 100, digits=1))%)")
    println("  On-Time Delivery: $(round(final_kpis.on_time_delivery * 100, digits=1))% (Target: $(round(state.target_kpis.on_time_delivery * 100, digits=1))%)")
    println()
    
    println("Efficiency Metrics:")
    println("  Orders per Hour: $(round(final_kpis.orders_per_hour, digits=1))")
    println("  Average Completion Time: $(round(final_kpis.average_completion_time, digits=1)) minutes")
    println("  Total Distance Traveled: $(round(final_kpis.total_distance_traveled, digits=1)) meters")
    println("  Energy Efficiency: $(round(final_kpis.energy_efficiency, digits=2)) meters per order")
    println()
    
    println("AGV Performance:")
    for agv in state.agvs
        utilization = get_agv_utilization_rate(agv, final_kpis.total_simulation_time)
        println("  AGV $(agv.id): $(agv.tasks_completed) tasks, $(round(utilization * 100, digits=1))% utilization, $(round(agv.total_distance_traveled, digits=1))m traveled")
    end
    
    println()
    println("Shift Performance:")
    for (shift_num, performance) in final_kpis.shift_performance
        println("  Shift $shift_num: $(round(performance * 100, digits=1))% on-time delivery")
    end
    
    println()
    
    # Calculate overall score
    overall_score, component_scores = calculate_kpi_score(final_kpis, state.target_kpis)
    println("=== PERFORMANCE SCORE ===")
    println("Overall Score: $(round(overall_score * 100, digits=1))/100")
    println("Component Scores:")
    println("  Idle Time Score: $(round(component_scores[1] * 100, digits=1))/100")
    println("  Utilization Score: $(round(component_scores[2] * 100, digits=1))/100")
    println("  On-Time Delivery Score: $(round(component_scores[3] * 100, digits=1))/100")
    
    println()
    println("Demo completed successfully!")
    return state, kpis_results
end

function test_vns_optimization()
    println("\n=== TESTING VNS OPTIMIZATION ===")
    
    # Create simulation state with more orders
    state = create_simulation_state(5, 1234)
    
    # Generate 2 hours of orders for optimization
    orders = generate_orders_for_time_period(state.order_generator, state.warehouse, 120.0, 0.0)
    for order in orders
        push!(state.orders, order)
        push!(state.pending_orders, order)
    end
    
    println("Running initial simulation for baseline...")
    run_simulation(state, 30.0)
    initial_kpis = calculate_warehouse_kpis(state.agvs, state.orders, state.current_time, state.kpi_history)
    
    println("Baseline KPIs:")
    println("  Idle Time: $(round(initial_kpis.agv_idle_time * 100, digits=1))%")
    println("  Utilization: $(round(initial_kpis.utilization_rate * 100, digits=1))%")
    println("  On-Time Delivery: $(round(initial_kpis.on_time_delivery * 100, digits=1))%")
    println("  Baseline Fitness: $(round(calculate_kpi_score(initial_kpis, Dict(:idle_time => 0.3, :utilization => 0.4, :on_time_delivery => 0.3))[1] * 100, digits=1))/100")
    
    println("\nRunning VNS optimization...")
    vns_config = create_default_vns_config()
    vns_config.max_iterations = 20  # Reduced for demo
    vns_config.max_no_improvement = 5
    
    optimized_solution = vns_optimize(state, vns_config)
    
    println("\nOptimization completed!")
    println("Final KPIs:")
    println("  Idle Time: $(round(optimized_solution.kpis.agv_idle_time * 100, digits=1))%")
    println("  Utilization: $(round(optimized_solution.kpis.utilization_rate * 100, digits=1))%")
    println("  On-Time Delivery: $(round(optimized_solution.kpis.on_time_delivery * 100, digits=1))%")
    println("  Final Fitness: $(round(optimized_solution.fitness * 100, digits=1))/100")
    
    improvement = ((optimized_solution.fitness - calculate_kpi_score(initial_kpis, Dict(:idle_time => 0.3, :utilization => 0.4, :on_time_delivery => 0.3))[1]) / 
                   calculate_kpi_score(initial_kpis, Dict(:idle_time => 0.3, :utilization => 0.4, :on_time_delivery => 0.3))[1]) * 100
    
    println("Improvement: $(round(improvement, digits=1))%")
    
    return optimized_solution
end

# Run the demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    println("Starting Warehouse Optimization System Demo...")
    
    try
        # Run basic example
        state, kpis_results = basic_warehouse_example()
        
        # Test VNS optimization
        optimized_solution = test_vns_optimization()
        
        println("\n=== DEMO COMPLETED SUCCESSFULLY ===")
        println("All components are working correctly!")
        
    catch e
        println("Error during demo: $e")
        println("Stack trace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
        end
    end
end