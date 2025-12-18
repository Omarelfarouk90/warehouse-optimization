"""
Debug script to understand the coordinate system issue
"""

include("src/core/warehouse.jl")
include("src/core/agv.jl")

function debug_coordinates()
    println("=" ^ 70)
    println("🔍 DEBUGGING COORDINATE SYSTEM")
    println("=" ^ 70)
    
    # Create warehouse and AGV
    warehouse = create_warehouse()
    agvs = initialize_agvs(1)
    agv = agvs[1]
    
    println("\n📍 COORDINATE SYSTEM DEBUG:")
    println("   AGV Start Position: $(agv.position)")
    println("   Grid Resolution: $(GRID_RESOLUTION)")
    println("   Input Dock: $(warehouse.input_dock)")
    println("   Output Dock: $(warehouse.output_dock)")
    
    # Test with a simple nearby target
    nearby_target = (5.0, 2.5)  # Same Y, different X
    println("\n🎯 TEST 1: Simple Horizontal Movement")
    println("   Target: $nearby_target")
    
    agv.target_position = nearby_target
    agv.state = MOVING
    
    println("   Initial state:")
    println("     Position: $(agv.position)")
    println("     Target: $(agv.target_position)")
    println("     State: $(agv.state)")
    
    # Move for a few steps
    for step in 1:5
        old_pos = agv.position
        update_agv_position!(agv, 0.5)
        new_pos = agv.position
        
        println("   Step $step: $(old_pos) → $(new_pos)")
        
        if agv.state != MOVING
            println("   ✅ Reached target in $step steps")
            break
        end
    end
    
    # Reset and test diagonal movement
    agv.position = (1.0, 2.5)
    agv.state = IDLE
    agv.target_position = nothing
    
    diagonal_target = (3.0, 3.5)  # Different X and Y
    println("\n🎯 TEST 2: Diagonal Movement (should be Cartesian)")
    println("   Target: $diagonal_target")
    
    agv.target_position = diagonal_target
    agv.state = MOVING
    
    println("   Initial state:")
    println("     Position: $(agv.position)")
    println("     Target: $(agv.target_position)")
    
    # Move for a few steps
    for step in 1:10
        old_pos = agv.position
        update_agv_position!(agv, 0.5)
        new_pos = agv.position
        
        dx = new_pos[1] - old_pos[1]
        dy = new_pos[2] - old_pos[2]
        
        movement_type = ""
        if abs(dx) > 0.01 && abs(dy) > 0.01
            movement_type = "❌ Diagonal"
        elseif abs(dx) > 0.01
            movement_type = "✅ Horizontal"
        elseif abs(dy) > 0.01
            movement_type = "✅ Vertical"
        else
            movement_type = "⏸️  No movement"
        end
        
        println("   Step $step: $(old_pos) → $(new_pos) [$movement_type]")
        
        if agv.state != MOVING
            println("   ✅ Reached target in $step steps")
            break
        end
    end
    
    println("\n" * "=" ^ 70)
    println("🔍 DEBUGGING COMPLETED")
    println("=" ^ 70)
end

# Run the debug
if abspath(PROGRAM_FILE) == @__FILE__
    try
        debug_coordinates()
    catch e
        println("❌ Error: $e")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
        end
    end
end