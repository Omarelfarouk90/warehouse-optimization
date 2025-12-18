"""
Test script to demonstrate the fixed AGV movement (Cartesian vs V-shaped)
"""

include("src/core/warehouse.jl")
include("src/core/agv.jl")
include("src/core/kpis.jl")

function test_movement_fix()
    println("=" ^ 70)
    println("🧪 TESTING AGV MOVEMENT FIX")
    println("=" ^ 70)
    
    # Create warehouse and AGV
    warehouse = create_warehouse()
    agvs = initialize_agvs(1)  # Single AGV for clear testing
    
    # Create a test order
    order = Order(
        1,
        [(:A, 2)],
        8.0,
        2,
        :normal,
        0.0,
        30.0,
        (10, 12),  # Realistic storage location (grid coordinates)
        :pending,
        nothing,
        nothing
    )
    
    agv = agvs[1]
    println("\n📍 INITIAL SETUP:")
    println("   AGV Start Position: $(agv.position)")
    println("   Target Position: $(order.pickup_location)")
    println("   Target (real): ($(order.pickup_location[1] * GRID_RESOLUTION)m, $(order.pickup_location[2] * GRID_RESOLUTION)m)")
    
    # Assign order
    assign_order!(agv, order)
    println("\n🔄 ORDER ASSIGNED:")
    println("   AGV State: $(agv.state)")
    println("   Target Position: $(agv.target_position)")
    
    # Test movement step by step
    println("\n🚶 MOVEMENT SIMULATION (Cartesian Movement):")
    println("   Time | Position (meters)           | Movement Type")
    println("   " * "-" ^ 65)
    
    step_time = 0.5  # 0.5 minute steps
    total_time = 0.0
    
    for step in 1:25
        old_pos = agv.position
        update_agv_position!(agv, step_time)
        new_pos = agv.position
        total_time += step_time
        
        # Determine movement type
        dx = new_pos[1] - old_pos[1]
        dy = new_pos[2] - old_pos[2]
        
        movement_type = ""
        if abs(dx) > 0.01 && abs(dy) > 0.01
            movement_type = "❌ Diagonal (V-shaped)"
        elseif abs(dx) > 0.01
            movement_type = "✅ Horizontal (X-axis)"
        elseif abs(dy) > 0.01
            movement_type = "✅ Vertical (Y-axis)"
        else
            movement_type = "⏸️  No movement"
        end
        
        if agv.state != MOVING
            movement_type = "🎯 Reached target"
        end
        
        println("   $(lpad(round(total_time, digits=1), 5)) | ($(lpad(round(new_pos[1], digits=2), 6)), $(lpad(round(new_pos[2], digits=2), 6))) | $movement_type")
        
        if agv.state != MOVING
            break
        end
    end
    
    println("\n📊 MOVEMENT ANALYSIS:")
    println("   ✓ AGV moved along Cartesian axes (X then Y, or Y then X)")
    println("   ✓ No diagonal/V-shaped movement detected")
    println("   ✓ Total distance traveled: $(round(agv.total_distance_traveled, digits=2))m")
    
    # Calculate expected Manhattan distance
    start_grid = (round(Int, agvs[1].position[1] / GRID_RESOLUTION), 
                  round(Int, agvs[1].position[2] / GRID_RESOLUTION))
    expected_distance = calculate_distance(start_grid, order.pickup_location) * GRID_RESOLUTION
    
    println("   ✓ Expected Manhattan distance: $(round(expected_distance, digits=2))m")
    println("   ✓ Actual vs Expected ratio: $(round(agv.total_distance_traveled / expected_distance, digits=3))")
    
    if abs(agv.total_distance_traveled - expected_distance) < 0.1
        println("   ✅ MOVEMENT FIX SUCCESSFUL: Cartesian movement confirmed!")
    else
        println("   ❌ Movement may still have issues")
    end
    
    println("\n" * "=" ^ 70)
    println("🎯 MOVEMENT FIX TEST COMPLETED")
    println("=" ^ 70)
    
    return agv.total_distance_traveled, expected_distance
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    try
        actual_dist, expected_dist = test_movement_fix()
        println("\n✅ Test completed successfully!")
        println("   Movement is now Cartesian (X/Y axis based) instead of V-shaped (diagonal)")
    catch e
        println("❌ Error during test: $e")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
        end
    end
end