"""
Final verification that AGV movement is now Cartesian (not V-shaped)
"""

include("src/core/warehouse.jl")
include("src/core/agv.jl")

function verify_movement_fix()
    println("=" ^ 70)
    println("✅ VERIFICATION: AGV MOVEMENT FIX")
    println("=" ^ 70)
    
    # Create warehouse and AGV
    warehouse = create_warehouse()
    agvs = initialize_agvs(1)
    agv = agvs[1]
    
    println("\n🔍 BEFORE FIX:")
    println("   ❌ AGVs moved in V-shaped diagonal patterns")
    println("   ❌ Movement was proportional on both X and Y axes simultaneously")
    println("   ❌ Distance calculation was Euclidean")
    
    println("\n🔧 AFTER FIX:")
    println("   ✅ AGVs move in Cartesian patterns (X-axis, then Y-axis)")
    println("   ✅ Movement is axis-aligned, one direction at a time")
    println("   ✅ Distance calculation is Manhattan-based")
    
    # Test the fix with diagonal target
    order = Order(
        1,
        [(:A, 2)],
        8.0,
        2,
        :normal,
        0.0,
        30.0,
        (8, 15),  # Diagonal from start: X increases, Y increases
        :pending,
        nothing,
        nothing
    )
    
    assign_order!(agv, order)
    
    println("\n🧪 TEST: Diagonal Target Movement")
    println("   Start: $(agv.position)")
    println("   Target: $(order.pickup_location)")
    println("   Expected: Horizontal first, then vertical")
    
    # Simulate movement
    movement_pattern = []
    for step in 1:20
        if agv.state != MOVING
            break
        end
        
        old_pos = agv.position
        update_agv_position!(agv, 0.5)
        new_pos = agv.position
        
        dx = new_pos[1] - old_pos[1]
        dy = new_pos[2] - old_pos[2]
        
        if abs(dx) > 0.01 && abs(dy) > 0.01
            push!(movement_pattern, "DIAGONAL")
        elseif abs(dx) > 0.01
            push!(movement_pattern, "HORIZONTAL")
        elseif abs(dy) > 0.01
            push!(movement_pattern, "VERTICAL")
        else
            push!(movement_pattern, "NONE")
        end
    end
    
    println("   Movement pattern: $(join(movement_pattern, " → "))")
    
    # Verify pattern
    has_horizontal = any(m -> m == "HORIZONTAL", movement_pattern)
    has_vertical = any(m -> m == "VERTICAL", movement_pattern)
    has_diagonal = any(m -> m == "DIAGONAL", movement_pattern)
    
    println("\n📊 VERIFICATION RESULTS:")
    println("   Has horizontal movement: $(has_horizontal ? "✅" : "❌")")
    println("   Has vertical movement: $(has_vertical ? "✅" : "❌")")
    println("   Has diagonal movement: $(has_diagonal ? "❌" : "✅")")
    
    if has_horizontal && has_vertical && !has_diagonal
        println("\n   🎉 MOVEMENT FIX CONFIRMED!")
        println("   AGVs now move in Cartesian X/Y axis patterns")
        println("   V-shaped diagonal movement has been eliminated")
    else
        println("\n   ❌ Movement fix may have issues")
    end
    
    println("\n" * "=" ^ 70)
    println("📋 SUMMARY OF CHANGES MADE:")
    println("=" ^ 70)
    println("1. Modified update_agv_position!() in agv.jl:")
    println("   - Changed from proportional Euclidean movement")
    println("   - To Cartesian movement (X-axis first, then Y-axis)")
    println("")
    println("2. Added calculate_euclidean_distance() in warehouse.jl:")
    println("   - For collision detection (keeps Euclidean for safety)")
    println("   - Manhattan distance remains for path planning")
    println("")
    println("3. Fixed collision detection in agv.jl:")
    println("   - Uses Euclidean distance for accurate collision checking")
    println("=" ^ 70)
    
    return !has_diagonal && has_horizontal && has_vertical
end

# Run verification
if abspath(PROGRAM_FILE) == @__FILE__
    try
        success = verify_movement_fix()
        if success
            println("\n✅ VERIFICATION PASSED: AGV movement fix is working correctly!")
        else
            println("\n❌ VERIFICATION FAILED: Issues may remain")
        end
    catch e
        println("❌ Error: $e")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
        end
    end
end