"""
WAREHOUSE TEXT VISUALIZATION DEMO
===================================
Shows input instance and AGV routes in text format (no graphics dependencies)
"""

using Random

# Load the complete system
include("complete_test.jl")

# ===== INPUT INSTANCE GENERATION =====

function generate_sample_instance()
    """Generate a sample problem instance for visualization"""
    
    println("=" ^ 70)
    println("📋 GENERATING INPUT INSTANCE")
    println("=" ^ 70)
    
    # Create warehouse
    warehouse = create_warehouse()
    
    # Create AGVs
    agvs = initialize_agvs(5)
    
    # Generate sample orders
    rng = MersenneTwister(42)
    orders = Order[]
    
    order_data = [
        # (crates, priority, item_type, description)
        (2, :urgent, :A, "Urgent medical supplies"),
        (5, :normal, :B, "Standard electronics parts"),
        (3, :urgent, :A, "Priority automotive components"),
        (1, :low, :C, "Low priority office supplies"),
        (4, :normal, :B, "Regular inventory restock"),
    ]
    
    for (i, (crates, priority, item_type, desc)) in enumerate(order_data)
        weight = crates * CRATE_WEIGHT_KG
        creation_time = (i - 1) * 5.0
        
        deadline_mult = priority == :urgent ? 15.0 : 
                       priority == :normal ? 30.0 : 60.0
        deadline = creation_time + deadline_mult
        
        # Find storage location
        storage_loc = find_nearest_storage(warehouse, item_type, weight)
        pickup_pos = storage_loc !== nothing ? storage_loc.position : (10, 10)
        
        order = Order(
            i, [(item_type, crates)], weight, crates,
            priority, creation_time, deadline, pickup_pos,
            :pending, nothing, nothing
        )
        
        push!(orders, order)
    end
    
    return warehouse, agvs, orders
end

function display_input_instance(warehouse, agvs, orders)
    """Display detailed input instance information"""
    
    println("\n📦 INPUT INSTANCE DETAILS")
    println("=" ^ 70)
    
    # Warehouse info
    println("\n🏭 WAREHOUSE CONFIGURATION:")
    println("   Dimensions: $(warehouse.dimensions[1])m × $(warehouse.dimensions[2])m")
    println("   Total Storage Locations: $(length(warehouse.storage_locations))")
    println("   Grid Resolution: $(GRID_RESOLUTION)m")
    println("   Input Dock: $(warehouse.input_dock)")
    println("   Output Dock: $(warehouse.output_dock)")
    
    # Storage breakdown
    zone_counts = Dict(:high => 0, :medium => 0, :low => 0)
    for loc in warehouse.storage_locations
        zone_counts[loc.zone] += 1
    end
    println("\n   Storage Zones:")
    println("   • High Frequency: $(zone_counts[:high]) locations")
    println("   • Medium Frequency: $(zone_counts[:medium]) locations")
    println("   • Low Frequency: $(zone_counts[:low]) locations")
    
    # AGV info
    println("\n🤖 AGV FLEET:")
    for agv in agvs
        println("   AGV $(agv.id):")
        println("      Position: $(agv.position)")
        println("      Capacity: $(AGV_CAPACITY_KG)kg / $(AGV_CAPACITY_CRATES) crates")
        println("      Speed: $(AGV_SPEED_M_PER_MIN)m/min")
        println("      State: $(agv.state)")
    end
    
    # Order info
    println("\n📋 ORDER LIST ($(length(orders)) orders):")
    println("   " * "-" ^ 66)
    println("   ID | Priority | Crates | Weight | Pickup Location | Deadline")
    println("   " * "-" ^ 66)
    
    for order in orders
        priority_icon = order.priority == :urgent ? "🔴" :
                       order.priority == :normal ? "🟡" : "🟢"
        
        println("   $(lpad(order.id, 2)) | $(priority_icon) $(rpad(string(order.priority), 6)) | " *
                "$(lpad(order.total_crates, 6)) | $(lpad(order.total_weight, 6))kg | " *
                "$(lpad(string(order.pickup_location), 15)) | $(lpad(round(order.deadline, digits=1), 8))min")
    end
    println("   " * "-" ^ 66)
    
    # Priority summary
    urgent_count = count(o -> o.priority == :urgent, orders)
    normal_count = count(o -> o.priority == :normal, orders)
    low_count = count(o -> o.priority == :low, orders)
    
    println("\n   Priority Breakdown:")
    println("   🔴 Urgent: $urgent_count orders ($(round(urgent_count/length(orders)*100, digits=1))%)")
    println("   🟡 Normal: $normal_count orders ($(round(normal_count/length(orders)*100, digits=1))%)")
    println("   🟢 Low: $low_count orders ($(round(low_count/length(orders)*100, digits=1))%)")
    
    println("\n" * "=" ^ 70)
end

function display_ascii_warehouse(warehouse, agvs, orders)
    """Display ASCII art visualization of warehouse"""
    
    println("\n🎨 ASCII WAREHOUSE LAYOUT")
    println("=" ^ 70)
    
    # Create grid
    width_cells = round(Int, WAREHOUSE_WIDTH / GRID_RESOLUTION)
    height_cells = round(Int, WAREHOUSE_HEIGHT / GRID_RESOLUTION)
    
    grid = fill(' ', height_cells, width_cells)
    
    # Place storage locations
    for loc in warehouse.storage_locations
        x, y = loc.position
        if 1 <= x <= width_cells && 1 <= y <= height_cells
            zone_char = loc.zone == :high ? '█' :
                       loc.zone == :medium ? '▓' : '░'
            grid[height_cells - y + 1, x] = zone_char
        end
    end
    
    # Place docks
    input_x, input_y = warehouse.input_dock
    output_x, output_y = warehouse.output_dock
    if 1 <= input_x <= width_cells && 1 <= height_cells - input_y + 1 <= height_cells
        grid[height_cells - input_y + 1, input_x] = 'I'
    end
    if 1 <= output_x <= width_cells && 1 <= height_cells - output_y + 1 <= height_cells
        grid[height_cells - output_y + 1, output_x] = 'O'
    end
    
    # Place AGVs
    for agv in agvs
        x = round(Int, agv.position[1] / GRID_RESOLUTION)
        y = round(Int, agv.position[2] / GRID_RESOLUTION)
        if 1 <= x <= width_cells && 1 <= height_cells - y + 1 <= height_cells
            grid[height_cells - y + 1, x] = Char('0' + agv.id)
        end
    end
    
    # Place orders
    for order in orders
        pickup_x, pickup_y = order.pickup_location
        if 1 <= pickup_x <= width_cells && 1 <= height_cells - pickup_y + 1 <= height_cells
            priority_char = order.priority == :urgent ? '!' :
                           order.priority == :normal ? '*' : '.'
            grid[height_cells - pickup_y + 1, pickup_x] = priority_char
        end
    end
    
    # Print grid with border
    println("\n   +" * "-" ^ width_cells * "+")
    for row in eachrow(grid)
        println("   |" * join(row) * "|")
    end
    println("   +" * "-" ^ width_cells * "+")
    
    println("\n   Legend:")
    println("   █ = High frequency storage    ▓ = Medium frequency    ░ = Low frequency")
    println("   I = Input dock                O = Output dock")
    println("   1-5 = AGV positions           ! = Urgent order        * = Normal order    . = Low priority order")
    println("=" ^ 70)
end

function display_agv_routes(warehouse, agvs, orders, assignments)
    """Display AGV routes and calculations"""
    
    println("\n🛣️  AGV ROUTES AND CALCULATIONS")
    println("=" ^ 70)
    
    total_distance = 0.0
    
    for (i, agv) in enumerate(agvs)
        if agv.current_task !== nothing
            order = agv.current_task
            
            println("\n📍 AGV $(agv.id) → Order $(order.id) ($(order.priority), $(order.total_crates) crates)")
            println("   " * "-" ^ 66)
            
            # Start position
            start_x = round(agv.position[1] / GRID_RESOLUTION)
            start_y = round(agv.position[2] / GRID_RESOLUTION)
            println("   Start Position: ($(agv.position[1])m, $(agv.position[2])m) = Grid ($start_x, $start_y)")
            
            # Pickup location
            pickup_x, pickup_y = order.pickup_location
            pickup_real_x = pickup_x * GRID_RESOLUTION
            pickup_real_y = pickup_y * GRID_RESOLUTION
            println("   Pickup Location: ($(pickup_real_x)m, $(pickup_real_y)m) = Grid ($pickup_x, $pickup_y)")
            
            # Output dock
            output_x, output_y = warehouse.output_dock
            output_real_x = output_x * GRID_RESOLUTION
            output_real_y = output_y * GRID_RESOLUTION
            println("   Output Dock: ($(output_real_x)m, $(output_real_y)m) = Grid ($output_x, $output_y)")
            
            # Calculate distances
            dist_to_pickup = calculate_distance(
                (round(Int, start_x), round(Int, start_y)),
                order.pickup_location
            ) * GRID_RESOLUTION
            
            dist_to_output = calculate_distance(
                order.pickup_location,
                warehouse.output_dock
            ) * GRID_RESOLUTION
            
            total_route_dist = dist_to_pickup + dist_to_output
            total_distance += total_route_dist
            
println("\n   Cartesian Route Segments:")
            # Calculate X and Y components for pickup segment
            pickup_dx = pickup_real_x - agv.position[1]
            pickup_dy = pickup_real_y - agv.position[2]
            
            # Calculate X and Y components for output segment  
            output_dx = output_real_x - pickup_real_x
            output_dy = output_real_y - pickup_real_y
            
            println("   ├─ Start → Pickup:")
            println("   │  ├─ Horizontal (X): $(round(abs(pickup_dx), digits=2))m")
            println("   │  └─ Vertical (Y):   $(round(abs(pickup_dy), digits=2))m")
            println("   ├─ Pickup → Output:")
            println("   │  ├─ Horizontal (X): $(round(abs(output_dx), digits=2))m")
            println("   │  └─ Vertical (Y):   $(round(abs(output_dy), digits=2))m")
            println("   └─ Total Manhattan Distance: $(round(total_route_dist, digits=2))m")
            
            # Time calculation
            travel_time = total_route_dist / AGV_SPEED_M_PER_MIN
            load_time_per_crate = 0.5  # 0.5 minutes per crate
            unload_time_per_crate = 0.5  # 0.5 minutes per crate
            load_time = load_time_per_crate * order.total_crates
            unload_time = unload_time_per_crate * order.total_crates
            total_time = travel_time + load_time + unload_time
            
            println("\n   Time Breakdown:")
            println("   ├─ Travel Time:  $(round(travel_time, digits=2)) min")
            println("   ├─ Load Time:    $(round(load_time, digits=2)) min")
            println("   ├─ Unload Time:  $(round(unload_time, digits=2)) min")
            println("   └─ Total Time:   $(round(total_time, digits=2)) min")
            
            # Deadline check
            completion_time = order.creation_time + total_time
            slack_time = order.deadline - completion_time
            on_time = slack_time >= 0
            status = on_time ? "✅ ON TIME" : "❌ DELAYED"
            
            println("\n   Deadline Analysis:")
            println("   ├─ Order Created:    $(round(order.creation_time, digits=1)) min")
            println("   ├─ Completion Time:  $(round(completion_time, digits=1)) min")
            println("   ├─ Deadline:         $(round(order.deadline, digits=1)) min")
            println("   ├─ Slack Time:       $(round(slack_time, digits=1)) min")
            println("   └─ Status:           $status")
        end
    end
    
    # Summary
    println("\n" * "=" ^ 70)
    println("📊 ROUTE SUMMARY")
    println("=" ^ 70)
    println("Total Distance (All AGVs): $(round(total_distance, digits=2))m")
    println("Average Distance per AGV:  $(round(total_distance / count(a -> a.current_task !== nothing, agvs), digits=2))m")
    println("Active AGVs:               $(count(a -> a.current_task !== nothing, agvs)) / $(length(agvs))")
    println("=" ^ 70)
end

# ===== MAIN DEMO FUNCTION =====

function run_text_visualization_demo()
    """Main text visualization demo"""
    
    println("\n" * "=" ^ 70)
    println("🎨 WAREHOUSE TEXT VISUALIZATION DEMO")
    println("=" ^ 70)
    
    # Generate instance
    warehouse, agvs, orders = generate_sample_instance()
    
    # Display input instance
    display_input_instance(warehouse, agvs, orders)
    
    # ASCII visualization
    display_ascii_warehouse(warehouse, agvs, orders)
    
    # Assign orders to AGVs (simple greedy)
    println("\n🔄 ASSIGNING ORDERS TO AGVs...")
    println("=" ^ 70)
    assignments = Dict{Int, Int}()
    
    for (i, order) in enumerate(orders)
        if i <= length(agvs)
            agvs[i].current_task = order
            order.assigned_agv = i
            assignments[order.id] = i
            println("   ✓ Order $(order.id) ($(order.priority), $(order.total_crates) crates) → AGV $(i)")
        end
    end
    
    # Display routes
    display_agv_routes(warehouse, agvs, orders, assignments)
    
    println("\n" * "=" ^ 70)
    println("✅ TEXT VISUALIZATION DEMO COMPLETED!")
    println("=" ^ 70)
    println("\nNote: Graphical visualizations (PNG, GIF) require Plots.jl to be")
    println("fully compiled. Run 'visualization_demo.jl' for graphical output.")
    println("=" ^ 70)
end

# Run the demo
if abspath(PROGRAM_FILE) == @__FILE__
    try
        run_text_visualization_demo()
    catch e
        println("❌ Error: $e")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
        end
    end
end
