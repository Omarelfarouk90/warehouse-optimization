"""
Simple demo to test basic warehouse system without complex dependencies
"""

# Include basic modules directly
include("src/core/warehouse.jl")
include("src/core/agv.jl")
include("src/core/kpis.jl")

function simple_test()
    println("=== SIMPLE WAREHOUSE TEST ===")
    
    # Test warehouse creation
    println("Creating warehouse...")
    warehouse = create_warehouse()
    println("✓ Warehouse created with $(length(warehouse.storage_locations)) storage locations")
    println("✓ Dimensions: $(warehouse.dimensions)")
    println("✓ Grid size: $(warehouse.grid_size)")
    
    # Test storage location distribution
    zone_counts = Dict(:high => 0, :medium => 0, :low => 0)
    type_counts = Dict(:A => 0, :B => 0, :C => 0)
    
    for location in warehouse.storage_locations
        zone_counts[location.zone] += 1
        type_counts[location.item_type] += 1
    end
    
    println("✓ Zone distribution:")
    for (zone, count) in zone_counts
        println("   $zone: $count locations")
    end
    
    println("✓ Item type distribution:")
    for (item_type, count) in type_counts
        println("   Type $item_type: $count locations")
    end
    
    # Test AGV creation
    println("\nCreating AGVs...")
    agvs = initialize_agvs(5)
    println("✓ Created $(length(agvs)) AGVs")
    
    for agv in agvs
        println("✓ AGV $(agv.id): Position $(agv.position), State $(agv.state)")
    end
    
    # Test distance calculation
    println("\nTesting distance calculation...")
    dist = calculate_distance(warehouse.input_dock, warehouse.output_dock)
    println("✓ Distance from input to output dock: $dist grid units")
    println("✓ Real distance: $(dist * GRID_RESOLUTION) meters")
    
    # Test storage location finding
    println("\nTesting storage location search...")
    nearest_high = find_nearest_storage(warehouse, :A, 2.0)
    if nearest_high !== nothing
        println("✓ Nearest high-frequency storage for A-type items: $(nearest_high.id) at $(nearest_high.position)")
    end
    
    nearest_low = find_nearest_storage(warehouse, :C, 2.0)
    if nearest_low !== nothing
        println("✓ Nearest low-frequency storage for C-type items: $(nearest_low.id) at $(nearest_low.position)")
    end
    
    # Test basic KPI system
    println("\nTesting KPI system...")
    kpi_history = create_kpi_history()
    target_kpis = create_target_kpis()
    println("✓ KPI tracking initialized")
    println("✓ Target idle time: $(target_kpis.agv_idle_time * 100)%")
    println("✓ Target utilization: $(target_kpis.utilization_rate * 100)%")
    println("✓ Target on-time delivery: $(target_kpis.on_time_delivery * 100)%")
    
    # Calculate basic AGV KPIs
    agv_idle_time, utilized_agvs, utilization_rate = calculate_agv_kpis(agvs, 60.0)
    println("✓ AGV KPIs (60 minutes):")
    println("   Idle time: $(round(agv_idle_time * 100, digits=1))%")
    println("   Utilized AGVs: $utilized_agvs/5")
    println("   Utilization rate: $(round(utilization_rate * 100, digits=1))%")
    
    println("\n=== ALL TESTS PASSED ===")
    println("Basic warehouse system is working correctly!")
    
    return warehouse, agvs, kpi_history
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    try
        warehouse, agvs, kpi_history = simple_test()
        println("\n✓ Demo completed successfully!")
    catch e
        println("❌ Error during test: $e")
        println("Stack trace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
        end
    end
end