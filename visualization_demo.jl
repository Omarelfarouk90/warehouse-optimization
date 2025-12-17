"""
WAREHOUSE VISUALIZATION AND ANIMATION DEMO
==========================================
Shows input instance, AGV routes, and animated simulation
"""

using Plots
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

# ===== STATIC VISUALIZATION =====

function visualize_warehouse_layout(warehouse, agvs, orders, filename="warehouse_layout.png")
    """Create static visualization of warehouse layout with AGVs and orders"""
    
    println("\n🎨 CREATING STATIC WAREHOUSE VISUALIZATION...")
    
    # Create plot
    plt = plot(size=(1200, 600), dpi=150, legend=:outertopright, 
               xlabel="X Position (meters)", ylabel="Y Position (meters)",
               title="V-Shaped Warehouse Layout - 10m × 5m",
               xlims=(0, WAREHOUSE_WIDTH), ylims=(0, WAREHOUSE_HEIGHT),
               aspect_ratio=:equal, grid=true)
    
    # Plot storage locations by zone
    for zone in [:high, :medium, :low]
        zone_locs = filter(loc -> loc.zone == zone, warehouse.storage_locations)
        if !isempty(zone_locs)
            xs = [loc.position[1] * GRID_RESOLUTION for loc in zone_locs]
            ys = [loc.position[2] * GRID_RESOLUTION for loc in zone_locs]
            
            color = zone == :high ? :red :
                   zone == :medium ? :orange : :yellow
            marker = :square
            
            scatter!(plt, xs, ys, 
                    label="$(titlecase(string(zone))) Frequency Storage",
                    color=color, marker=marker, markersize=3, alpha=0.6)
        end
    end
    
    # Plot input/output docks
    input_x = warehouse.input_dock[1] * GRID_RESOLUTION
    input_y = warehouse.input_dock[2] * GRID_RESOLUTION
    output_x = warehouse.output_dock[1] * GRID_RESOLUTION
    output_y = warehouse.output_dock[2] * GRID_RESOLUTION
    
    scatter!(plt, [input_x], [input_y], 
            label="Input Dock", color=:green, marker=:diamond, 
            markersize=10, markerstrokewidth=2)
    scatter!(plt, [output_x], [output_y], 
            label="Output Dock", color=:blue, marker=:diamond, 
            markersize=10, markerstrokewidth=2)
    
    # Plot AGV positions
    for agv in agvs
        scatter!(plt, [agv.position[1]], [agv.position[2]], 
                label="AGV $(agv.id)",
                color=:purple, marker=:circle, markersize=8,
                markerstrokewidth=2, markerstrokecolor=:black)
        
        # Add AGV label
        annotate!(plt, agv.position[1] + 0.3, agv.position[2] + 0.3, 
                 text("AGV$(agv.id)", :purple, :left, 8))
    end
    
    # Plot order pickup locations
    for order in orders
        pickup_x = order.pickup_location[1] * GRID_RESOLUTION
        pickup_y = order.pickup_location[2] * GRID_RESOLUTION
        
        marker_color = order.priority == :urgent ? :red :
                      order.priority == :normal ? :orange : :green
        
        scatter!(plt, [pickup_x], [pickup_y],
                label="", color=marker_color, marker=:star5,
                markersize=6, alpha=0.8)
        
        # Add order label
        annotate!(plt, pickup_x + 0.2, pickup_y + 0.2,
                 text("O$(order.id)", marker_color, :left, 7))
    end
    
    # Save plot
    savefig(plt, filename)
    println("✅ Static visualization saved to: $filename")
    
    return plt
end

function visualize_agv_routes(warehouse, agvs, orders, assignments, filename="agv_routes.png")
    """Visualize AGV routes to assigned orders"""
    
    println("\n🛣️  CREATING AGV ROUTE VISUALIZATION...")
    
    # Create plot
    plt = plot(size=(1200, 600), dpi=150, legend=:outertopright,
               xlabel="X Position (meters)", ylabel="Y Position (meters)",
               title="AGV Routes - Optimized Paths",
               xlims=(0, WAREHOUSE_WIDTH), ylims=(0, WAREHOUSE_HEIGHT),
               aspect_ratio=:equal, grid=true)
    
    # Plot storage locations (lighter)
    all_xs = [loc.position[1] * GRID_RESOLUTION for loc in warehouse.storage_locations]
    all_ys = [loc.position[2] * GRID_RESOLUTION for loc in warehouse.storage_locations]
    scatter!(plt, all_xs, all_ys, label="Storage Locations",
            color=:lightgray, marker=:square, markersize=2, alpha=0.3)
    
    # Plot docks
    input_x = warehouse.input_dock[1] * GRID_RESOLUTION
    input_y = warehouse.input_dock[2] * GRID_RESOLUTION
    output_x = warehouse.output_dock[1] * GRID_RESOLUTION
    output_y = warehouse.output_dock[2] * GRID_RESOLUTION
    
    scatter!(plt, [input_x], [input_y], label="Input Dock",
            color=:green, marker=:diamond, markersize=10)
    scatter!(plt, [output_x], [output_y], label="Output Dock",
            color=:blue, marker=:diamond, markersize=10)
    
    # Colors for different AGVs
    agv_colors = [:purple, :red, :blue, :orange, :brown]
    
    # Plot routes for each AGV
    for (i, agv) in enumerate(agvs)
        if agv.current_task !== nothing
            order = agv.current_task
            
            # AGV start position
            start_x = agv.position[1]
            start_y = agv.position[2]
            
            # Pickup location
            pickup_x = order.pickup_location[1] * GRID_RESOLUTION
            pickup_y = order.pickup_location[2] * GRID_RESOLUTION
            
            # Route: Start -> Pickup -> Output
            route_x = [start_x, pickup_x, output_x]
            route_y = [start_y, pickup_y, output_y]
            
            # Plot route
            plot!(plt, route_x, route_y,
                 label="AGV $(agv.id) Route",
                 color=agv_colors[i], linewidth=2, arrow=true,
                 linestyle=:dash)
            
            # Plot AGV position
            scatter!(plt, [start_x], [start_y],
                    label="", color=agv_colors[i], marker=:circle,
                    markersize=8, markerstrokewidth=2)
            
            # Plot pickup location
            scatter!(plt, [pickup_x], [pickup_y],
                    label="Order $(order.id) ($(order.priority))",
                    color=agv_colors[i], marker=:star5, markersize=8)
            
            # Calculate and display distance
            dist_to_pickup = calculate_distance(
                (round(Int, start_x / GRID_RESOLUTION), round(Int, start_y / GRID_RESOLUTION)),
                order.pickup_location
            ) * GRID_RESOLUTION
            
            dist_to_output = calculate_distance(
                order.pickup_location,
                (round(Int, output_x / GRID_RESOLUTION), round(Int, output_y / GRID_RESOLUTION))
            ) * GRID_RESOLUTION
            
            total_dist = dist_to_pickup + dist_to_output
            
            # Annotate with distance
            mid_x = (start_x + pickup_x) / 2
            mid_y = (start_y + pickup_y) / 2
            annotate!(plt, mid_x, mid_y,
                     text("$(round(total_dist, digits=1))m", agv_colors[i], :center, 8))
        end
    end
    
    # Save plot
    savefig(plt, filename)
    println("✅ Route visualization saved to: $filename")
    
    return plt
end

# ===== ANIMATION =====

function create_agv_animation(warehouse, agvs, orders, assignments, filename="agv_animation.gif")
    """Create animated GIF of AGV movement"""
    
    println("\n🎬 CREATING AGV ANIMATION...")
    println("   This may take a moment...")
    
    # Animation parameters
    n_frames = 50
    fps = 10
    
    # Create animation
    anim = @animate for frame in 1:n_frames
        t = (frame - 1) / n_frames  # Time parameter 0 to 1
        
        # Create plot for this frame
        plt = plot(size=(1200, 600), dpi=100,
                   xlabel="X Position (meters)", ylabel="Y Position (meters)",
                   title="AGV Movement Animation - Frame $frame/$n_frames ($(round(t*100, digits=0))%)",
                   xlims=(0, WAREHOUSE_WIDTH), ylims=(0, WAREHOUSE_HEIGHT),
                   aspect_ratio=:equal, grid=true, legend=:outertopright)
        
        # Plot storage locations
        all_xs = [loc.position[1] * GRID_RESOLUTION for loc in warehouse.storage_locations]
        all_ys = [loc.position[2] * GRID_RESOLUTION for loc in warehouse.storage_locations]
        scatter!(plt, all_xs, all_ys, label="Storage",
                color=:lightgray, marker=:square, markersize=2, alpha=0.2)
        
        # Plot docks
        input_x = warehouse.input_dock[1] * GRID_RESOLUTION
        input_y = warehouse.input_dock[2] * GRID_RESOLUTION
        output_x = warehouse.output_dock[1] * GRID_RESOLUTION
        output_y = warehouse.output_dock[2] * GRID_RESOLUTION
        
        scatter!(plt, [input_x], [input_y], label="Input",
                color=:green, marker=:diamond, markersize=8)
        scatter!(plt, [output_x], [output_y], label="Output",
                color=:blue, marker=:diamond, markersize=8)
        
        # Animate each AGV
        agv_colors = [:purple, :red, :blue, :orange, :brown]
        
        for (i, agv) in enumerate(agvs)
            if agv.current_task !== nothing
                order = agv.current_task
                
                # Positions
                start_x = agv.position[1]
                start_y = agv.position[2]
                pickup_x = order.pickup_location[1] * GRID_RESOLUTION
                pickup_y = order.pickup_location[2] * GRID_RESOLUTION
                
                # Animate movement: Start -> Pickup (first half) -> Output (second half)
                if t < 0.5
                    # Moving to pickup
                    progress = t * 2  # 0 to 1
                    current_x = start_x + (pickup_x - start_x) * progress
                    current_y = start_y + (pickup_y - start_y) * progress
                    status = "→ Pickup"
                else
                    # Moving to output
                    progress = (t - 0.5) * 2  # 0 to 1
                    current_x = pickup_x + (output_x - pickup_x) * progress
                    current_y = pickup_y + (output_y - pickup_y) * progress
                    status = "→ Output"
                end
                
                # Plot AGV current position
                scatter!(plt, [current_x], [current_y],
                        label="AGV $(agv.id) $status",
                        color=agv_colors[i], marker=:circle,
                        markersize=10, markerstrokewidth=2,
                        markerstrokecolor=:black)
                
                # Plot trail
                if t < 0.5
                    trail_x = [start_x, current_x]
                    trail_y = [start_y, current_y]
                else
                    trail_x = [start_x, pickup_x, current_x]
                    trail_y = [start_y, pickup_y, current_y]
                end
                
                plot!(plt, trail_x, trail_y, label="",
                     color=agv_colors[i], linewidth=2, alpha=0.5)
                
                # Plot pickup location (star when not picked up)
                if t < 0.5
                    scatter!(plt, [pickup_x], [pickup_y], label="",
                            color=agv_colors[i], marker=:star5, markersize=8)
                end
            end
        end
    end
    
    # Save animation
    gif(anim, filename, fps=fps)
    println("✅ Animation saved to: $filename")
    println("   Duration: $(n_frames/fps) seconds at $(fps) fps")
    
    return filename
end

# ===== MAIN DEMO FUNCTION =====

function run_visualization_demo()
    """Main visualization demo"""
    
    println("\n" * "=" ^ 70)
    println("🎨 WAREHOUSE VISUALIZATION DEMO")
    println("=" ^ 70)
    
    # Generate instance
    warehouse, agvs, orders = generate_sample_instance()
    
    # Display input instance
    display_input_instance(warehouse, agvs, orders)
    
    # Assign orders to AGVs (simple greedy)
    println("\n🔄 ASSIGNING ORDERS TO AGVs...")
    assignments = Dict{Int, Int}()
    
    for (i, order) in enumerate(orders)
        if i <= length(agvs)
            agvs[i].current_task = order
            order.assigned_agv = i
            assignments[order.id] = i
            println("   ✓ Order $(order.id) → AGV $(i)")
        end
    end
    
    # Create visualizations
    println("\n📊 GENERATING VISUALIZATIONS...")
    
    # 1. Static warehouse layout
    visualize_warehouse_layout(warehouse, agvs, orders, 
                               "warehouse_layout.png")
    
    # 2. AGV routes
    visualize_agv_routes(warehouse, agvs, orders, assignments,
                        "agv_routes.png")
    
    # 3. Animation
    create_agv_animation(warehouse, agvs, orders, assignments,
                        "agv_animation.gif")
    
    println("\n" * "=" ^ 70)
    println("✅ VISUALIZATION DEMO COMPLETED!")
    println("=" ^ 70)
    println("\n📁 Generated Files:")
    println("   1. warehouse_layout.png  - Static warehouse layout")
    println("   2. agv_routes.png        - AGV routes with distances")
    println("   3. agv_animation.gif     - Animated AGV movement")
    println("\nAll files saved in: $(pwd())")
    println("=" ^ 70)
end

# Run the demo
if abspath(PROGRAM_FILE) == @__FILE__
    try
        run_visualization_demo()
    catch e
        println("❌ Error: $e")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
        end
    end
end
