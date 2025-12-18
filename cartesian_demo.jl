"""
Demo to showcase the new Cartesian AGV movement system
"""

include("src/core/warehouse.jl")
include("src/core/agv.jl")
include("src/core/kpis.jl")

function showcase_cartesian_movement()
    println("=" ^ 70)
    println("📐 CARTESIAN AGV MOVEMENT SHOWCASE")
    println("=" ^ 70)
    
    println("\n🔍 MOVEMENT SYSTEM OVERVIEW:")
    println("   ✅ OLD SYSTEM: V-shaped diagonal movement")
    println("      - AGVs moved proportionally on both X and Y axes")
    println("      - Created unrealistic diagonal paths through warehouse")
    println("      - Used Euclidean distance calculations")
    println("")
    println("   ✅ NEW SYSTEM: Cartesian axis-aligned movement")
    println("      - AGVs move along one axis at a time")
    println("      - Realistic warehouse aisle movement")
    println("      - Manhattan distance calculations")
    println("      - X-axis movement first, then Y-axis")
    
    # Create test scenarios
    scenarios = [
        ("Scenario 1: Horizontal Only", (6.0, 2.5), "Pure X-axis movement"),
        ("Scenario 2: Vertical Only", (2.0, 4.0), "Pure Y-axis movement"), 
        ("Scenario 3: Diagonal Target", (5.0, 4.0), "X then Y movement"),
        ("Scenario 4: Complex Path", (7.0, 1.0), "X then Y movement"),
    ]
    
    warehouse = create_warehouse()
    
    for (i, (name, target_pos, description)) in enumerate(scenarios)
        println("\n" * "=" ^ 70)
        println("📍 $name")
        println("=" ^ 70)
        println("   Description: $description")
        
        # Create AGV for this scenario
        agvs = initialize_agvs(1)
        agv = agvs[1]
        
        # Create test order
        order = Order(
            i,
            [(:A, 2)],
            8.0,
            2,
            :normal,
            0.0,
            30.0,
            (round(Int, target_pos[1] / GRID_RESOLUTION), 
             round(Int, target_pos[2] / GRID_RESOLUTION)),
            :pending,
            nothing,
            nothing
        )
        
        assign_order!(agv, order)
        
        println("   Start Position: $(agv.position)")
        println("   Target Position: $(order.pickup_location)")
        println("   Target (real): $target_pos")
        
        # Calculate expected Cartesian path
        dx = target_pos[1] - agv.position[1]
        dy = target_pos[2] - agv.position[2]
        
        println("\n   🧭 Planned Cartesian Movement:")
        if abs(dx) > 0.01
            println("   ├─ Step 1: Move $(abs(dx))m horizontally ($(dx > 0 ? "right" : "left"))")
        end
        if abs(dy) > 0.01
            println("   └─ Step 2: Move $(abs(dy))m vertically ($(dy > 0 ? "up" : "down"))")
        end
        
        println("\n   🚶 Simulating Movement (0.5min steps):")
        println("   Step | Position       | Movement Type     | Distance Remaining")
        println("   " * "-" ^ 70)
        
        step_num = 0
        while agv.state == MOVING && step_num < 20
            step_num += 1
            old_pos = agv.position
            update_agv_position!(agv, 0.5)
            new_pos = agv.position
            
            # Determine movement type
            dx_step = new_pos[1] - old_pos[1]
            dy_step = new_pos[2] - old_pos[2]
            
            movement_type = ""
            if abs(dx_step) > 0.01 && abs(dy_step) > 0.01
                movement_type = "❌ Diagonal"
            elseif abs(dx_step) > 0.01
                movement_type = "✅ Horizontal"
            elseif abs(dy_step) > 0.01
                movement_type = "✅ Vertical"
            else
                movement_type = "⏸️  None"
            end
            
            # Calculate remaining distance
            remaining_dx = target_pos[1] - new_pos[1]
            remaining_dy = target_pos[2] - new_pos[2]
            remaining_dist = sqrt(remaining_dx^2 + remaining_dy^2)
            
            println("   $(lpad(step_num, 4)) | $(rpad("($(round(new_pos[1], digits=1)), $(round(new_pos[2], digits=1)))", 14)) | $(rpad(movement_type, 16)) | $(lpad(round(remaining_dist, digits=2), 6))m")
            
            if agv.state != MOVING
                println("   ✅ Target reached in $step_num steps!")
                break
            end
        end
        
        # Calculate performance metrics
        expected_distance = abs(dx) + abs(dy)  # Manhattan
        actual_distance = agv.total_distance_traveled
        
        println("\n   📊 Movement Analysis:")
        println("   Expected Manhattan Distance: $(round(expected_distance, digits=2))m")
        println("   Actual Distance Traveled:   $(round(actual_distance, digits=2))m")
        println("   Efficiency Ratio:           $(round(actual_distance / expected_distance, digits=3))")
        
        if abs(actual_distance - expected_distance) < 0.1
            println("   ✅ Perfect Cartesian movement achieved!")
        else
            println("   ⚠️  Minor deviation from ideal path")
        end
    end
    
    println("\n" * "=" ^ 70)
    println("🎯 CARTESIAN MOVEMENT BENEFITS:")
    println("=" ^ 70)
    println("✅ 1. Realistic Warehouse Movement")
    println("   - AGVs follow aisle patterns")
    println("   - No cutting through storage racks")
    println("   - Better represents real warehouse operations")
    println("")
    println("✅ 2. Predictable Paths")
    println("   - Easy to track and optimize")
    println("   - Consistent movement patterns")
    println("   - Better collision avoidance")
    println("")
    println("✅ 3. Accurate Distance Calculations")
    println("   - Manhattan distance matches actual movement")
    println("   - Better time estimates")
    println("   - More accurate scheduling")
    println("")
    println("✅ 4. Improved Visualization")
    println("   - Clear X/Y axis movement display")
    println("   - Easy to understand paths")
    println("   - Better debugging and analysis")
    println("=" ^ 70)
    
    return true
end

# Run showcase
if abspath(PROGRAM_FILE) == @__FILE__
    try
        showcase_cartesian_movement()
        println("\n✅ Cartesian movement showcase completed successfully!")
        println("\n📝 Next steps:")
        println("   1. Run visualization_demo.jl to see animated Cartesian movement")
        println("   2. Check agv_animation.gif for visual confirmation")
        println("   3. Review agv_routes.png for static path visualization")
    catch e
        println("❌ Error: $e")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
        end
    end
end