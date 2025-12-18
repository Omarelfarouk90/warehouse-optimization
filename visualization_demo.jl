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
    """Visualize AGV routes with Cartesian movement patterns"""
    
    println("\n🛣️  CREATING AGV CARTESIAN ROUTE VISUALIZATION...")
    
    # Create plot
    plt = plot(size=(1200, 600), dpi=150, legend=:outertopright,
               xlabel="X Position (meters)", ylabel="Y Position (meters)",
               title="AGV Cartesian Routes - X/Y Axis Movement",
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
    
    # Plot Cartesian routes for each AGV
    for (i, agv) in enumerate(agvs)
        if agv.current_task !== nothing
            order = agv.current_task
            
            # AGV start position
            start_x = agv.position[1]
            start_y = agv.position[2]
            
            # Pickup location
            pickup_x = order.pickup_location[1] * GRID_RESOLUTION
            pickup_y = order.pickup_location[2] * GRID_RESOLUTION
            
            # Cartesian route: Start -> (pickup_x, start_y) -> pickup -> (pickup_x, output_y) -> output
            # This shows step-by-step X/Y movement
            waypoint1_x = pickup_x
            waypoint1_y = start_y
            
            route_x = [start_x, waypoint1_x, pickup_x, pickup_x, output_x]
            route_y = [start_y, waypoint1_y, pickup_y, output_y, output_y]
            
            # Plot Cartesian route with distinct segments
            # Segment 1: Horizontal to pickup X
            plot!(plt, [start_x, waypoint1_x], [start_y, waypoint1_y],
                 label="", color=agv_colors[i], linewidth=3, 
                 linestyle=:solid, alpha=0.8)
            
            # Segment 2: Vertical to pickup Y  
            plot!(plt, [waypoint1_x, pickup_x], [waypoint1_y, pickup_y],
                 label="", color=agv_colors[i], linewidth=3,
                 linestyle=:solid, alpha=0.8)
            
            # Segment 3: Vertical to output Y
            plot!(plt, [pickup_x, pickup_x], [pickup_y, output_y],
                 label="", color=agv_colors[i], linewidth=3,
                 linestyle=:dash, alpha=0.6)
            
            # Segment 4: Horizontal to output X
            plot!(plt, [pickup_x, output_x], [output_y, output_y],
                 label="", color=agv_colors[i], linewidth=3,
                 linestyle=:dash, alpha=0.6)
            
            # Plot AGV position
            scatter!(plt, [start_x], [start_y],
                    label="AGV $(agv.id) Start", color=agv_colors[i], 
                    marker=:circle, markersize=10, markerstrokewidth=2)
            
            # Plot intermediate waypoint
            scatter!(plt, [waypoint1_x], [waypoint1_y],
                    label="", color=agv_colors[i], marker=:diamond,
                    markersize=6, alpha=0.7)
            
            # Plot pickup location
            scatter!(plt, [pickup_x], [pickup_y],
                    label="Order $(order.id) ($(order.priority))",
                    color=agv_colors[i], marker=:star5, markersize=8)
            
            # Calculate distances for each segment
            dist_horizontal_pickup = abs(pickup_x - start_x)
            dist_vertical_pickup = abs(pickup_y - start_y)
            dist_vertical_output = abs(output_y - pickup_y)
            dist_horizontal_output = abs(output_x - pickup_x)
            
            total_dist = dist_horizontal_pickup + dist_vertical_pickup + 
                       dist_vertical_output + dist_horizontal_output
            
            # Annotate with segment distances
            # Annotate horizontal segment to pickup
            mid_h_x = (start_x + waypoint1_x) / 2
            annotate!(plt, mid_h_x, waypoint1_y + 0.1,
                     text("H:$(round(dist_horizontal_pickup, digits=1))m", 
                           agv_colors[i], :center, 7))
            
            # Annotate vertical segment to pickup
            mid_v_x = waypoint1_x + 0.1
            mid_v_y = (waypoint1_y + pickup_y) / 2
            annotate!(plt, mid_v_x, mid_v_y,
                     text("V:$(round(dist_vertical_pickup, digits=1))m", 
                           agv_colors[i], :center, 7))
            
            # Total distance annotation
            annotate!(plt, (start_x + output_x) / 2, output_y + 0.3,
                     text("Total: $(round(total_dist, digits=1))m", 
                           agv_colors[i], :center, 8, :bold))
            
            # Add movement direction indicators
            arrow_length = 0.3
            # Horizontal arrow to pickup
            if dist_horizontal_pickup > 0.1
                arrow_dir = dist_horizontal_pickup > 0 ? 1 : -1
                plot!(plt, [start_x + arrow_dir * dist_horizontal_pickup/2 - arrow_dir * arrow_length/2, 
                            start_x + arrow_dir * dist_horizontal_pickup/2 + arrow_dir * arrow_length/2], 
                        [waypoint1_y, waypoint1_y],
                       label="", color=agv_colors[i], linewidth=2, arrow=:closed)
            end
            
            # Vertical arrow to pickup
            if dist_vertical_pickup > 0.1
                arrow_dir = dist_vertical_pickup > 0 ? 1 : -1
                plot!(plt, [waypoint1_x, waypoint1_x], 
                        [start_y + arrow_dir * dist_vertical_pickup/2 - arrow_dir * arrow_length/2,
                         start_y + arrow_dir * dist_vertical_pickup/2 + arrow_dir * arrow_length/2],
                       label="", color=agv_colors[i], linewidth=2, arrow=:closed)
            end
        end
    end
    
    # Save plot
    savefig(plt, filename)
    println("✅ Route visualization saved to: $filename")
    
    return plt
end

# ===== ANIMATION =====

function create_agv_animation(warehouse, agvs, orders, assignments, filename="agv_animation.gif")
    """Create animated GIF of AGV movement showing Cartesian patterns with demand/storage markers"""
    
    println("\n🎬 CREATING AGV ANIMATION WITH CARTESIAN MOVEMENT & MARKERS...")
    println("   This may take a moment...")
    
    # Animation parameters - more frames for smoother Cartesian visualization
    n_frames = 100
    fps = 10
    
    # Create animation
    anim = @animate for frame in 1:n_frames
        t = (frame - 1) / n_frames  # Time parameter 0 to 1
        
        # Create plot for this frame
        plt = plot(size=(1400, 700), dpi=100,
                   xlabel="X Position (meters)", ylabel="Y Position (meters)",
                   title="AGV Cartesian Movement with Demand/Storage Markers - Frame $frame/$n_frames ($(round(t*100, digits=0))%)",
                   xlims=(0, WAREHOUSE_WIDTH), ylims=(0, WAREHOUSE_HEIGHT),
                   aspect_ratio=:equal, grid=true, legend=:outertopright)
        
        # Plot storage locations by zone with distinct colors
        for zone in [:high, :medium, :low]
            zone_locs = filter(loc -> loc.zone == zone, warehouse.storage_locations)
            if !isempty(zone_locs)
                xs = [loc.position[1] * GRID_RESOLUTION for loc in zone_locs]
                ys = [loc.position[2] * GRID_RESOLUTION for loc in zone_locs]
                
                color = zone == :high ? :red :
                       zone == :medium ? :orange : :yellow
                alpha = zone == :high ? 0.4 : zone == :medium ? 0.3 : 0.2
                
                scatter!(plt, xs, ys, label="$(titlecase(string(zone))) Storage",
                        color=color, marker=:square, markersize=4, alpha=alpha)
            end
        end
        
        # Plot docks with enhanced visibility
        input_x = warehouse.input_dock[1] * GRID_RESOLUTION
        input_y = warehouse.input_dock[2] * GRID_RESOLUTION
        output_x = warehouse.output_dock[1] * GRID_RESOLUTION
        output_y = warehouse.output_dock[2] * GRID_RESOLUTION
        
        scatter!(plt, [input_x], [input_y], label="Input Dock (Demand)",
                color=:green, marker=:diamond, markersize=12, markerstrokewidth=2)
        scatter!(plt, [output_x], [output_y], label="Output Dock",
                color=:blue, marker=:diamond, markersize=12, markerstrokewidth=2)
        
        # Add demand location markers (customer pickup areas)
        demand_locations = [
            (input_x, input_y + 0.3, "Demand A"),
            (input_x, input_y - 0.3, "Demand B"),
            (input_x + 0.3, input_y, "Demand C")
        ]
        
        for (dx, dy, label) in demand_locations
            scatter!(plt, [dx], [dy], label="",
                    color=:lightgreen, marker=:triangle, markersize=8, alpha=0.7)
            annotate!(plt, dx + 0.15, dy, text(label, :darkgreen, :left, 6))
        end
        
        # Animate each AGV with Cartesian movement visualization
        agv_colors = [:purple, :red, :blue, :orange, :brown]
        
        for (i, agv) in enumerate(agvs)
            if agv.current_task !== nothing
                order = agv.current_task
                
                # Positions
                start_x = agv.position[1]
                start_y = agv.position[2]
                pickup_x = order.pickup_location[1] * GRID_RESOLUTION
                pickup_y = order.pickup_location[2] * GRID_RESOLUTION
                
                # Calculate Cartesian path with intermediate waypoint
                # Phase 1: Move horizontally to pickup_x, keep start_y
                # Phase 2: Move vertically to pickup_y, keep pickup_x
                # Phase 3: Move vertically to output_y, keep pickup_x
                # Phase 4: Move horizontally to output_x, keep output_y
                
                total_distance_x_to_pickup = abs(pickup_x - start_x)
                total_distance_y_to_pickup = abs(pickup_y - start_y)
                total_distance_x_to_output = abs(output_x - pickup_x)
                total_distance_y_to_output = abs(output_y - pickup_y)
                
                total_distance = total_distance_x_to_pickup + total_distance_y_to_pickup + 
                               total_distance_x_to_output + total_distance_y_to_output
                
                current_distance = t * total_distance
                
                # Determine current position along Cartesian path
                current_x = start_x
                current_y = start_y
                phase = ""
                trail_x = [start_x]
                trail_y = [start_y]
                
                if current_distance <= total_distance_x_to_pickup
                    # Phase 1: Horizontal to pickup
                    phase = "→ X-Axis"
                    progress = current_distance / total_distance_x_to_pickup
                    current_x = start_x + (pickup_x - start_x) * progress
                    current_y = start_y
                    push!(trail_x, current_x)
                    push!(trail_y, current_y)
                    
                elseif current_distance <= total_distance_x_to_pickup + total_distance_y_to_pickup
                    # Phase 2: Vertical to pickup
                    phase = "→ Y-Axis"
                    # Complete horizontal movement first
                    push!(trail_x, pickup_x)
                    push!(trail_y, start_y)
                    
                    remaining_distance = current_distance - total_distance_x_to_pickup
                    progress = remaining_distance / total_distance_y_to_pickup
                    current_x = pickup_x
                    current_y = start_y + (pickup_y - start_y) * progress
                    push!(trail_x, current_x)
                    push!(trail_y, current_y)
                    
                elseif current_distance <= total_distance_x_to_pickup + total_distance_y_to_pickup + total_distance_y_to_output
                    # Phase 3: Vertical to output level
                    phase = "→ Y-Axis"
                    push!(trail_x, pickup_x)
                    push!(trail_y, start_y)
                    push!(trail_x, pickup_x)
                    push!(trail_y, pickup_y)
                    
                    remaining_distance = current_distance - total_distance_x_to_pickup - total_distance_y_to_pickup
                    progress = remaining_distance / total_distance_y_to_output
                    current_x = pickup_x
                    current_y = pickup_y + (output_y - pickup_y) * progress
                    push!(trail_x, current_x)
                    push!(trail_y, current_y)
                    
                else
                    # Phase 4: Horizontal to output
                    phase = "→ X-Axis"
                    push!(trail_x, pickup_x)
                    push!(trail_y, start_y)
                    push!(trail_x, pickup_x)
                    push!(trail_y, pickup_y)
                    push!(trail_x, pickup_x)
                    push!(trail_y, output_y)
                    
                    remaining_distance = current_distance - total_distance_x_to_pickup - total_distance_y_to_pickup - total_distance_y_to_output
                    progress = remaining_distance / total_distance_x_to_output
                    current_x = pickup_x + (output_x - pickup_x) * progress
                    current_y = output_y
                    push!(trail_x, current_x)
                    push!(trail_y, current_y)
                end
                
                # Plot AGV current position with phase indicator
                scatter!(plt, [current_x], [current_y],
                        label="AGV $(agv.id) $phase",
                        color=agv_colors[i], marker=:circle,
                        markersize=10, markerstrokewidth=2,
                        markerstrokecolor=:black)
                
                # Plot Cartesian trail properly to avoid diagonal connections
                if phase == "→ X-Axis"
                    if current_distance <= total_distance_x_to_pickup
                        # Phase 1: Horizontal to pickup
                        plot!(plt, [start_x, current_x], [start_y, start_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                    else
                        # Phase 4: Horizontal to output
                        # Plot all completed segments
                        plot!(plt, [start_x, pickup_x], [start_y, start_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                        plot!(plt, [pickup_x, pickup_x], [start_y, pickup_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                        plot!(plt, [pickup_x, pickup_x], [pickup_y, output_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                        plot!(plt, [pickup_x, current_x], [output_y, output_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                    end
                elseif phase == "→ Y-Axis"
                    if current_distance <= total_distance_x_to_pickup + total_distance_y_to_pickup
                        # Phase 2: Vertical to pickup
                        plot!(plt, [start_x, pickup_x], [start_y, start_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                        plot!(plt, [pickup_x, pickup_x], [start_y, current_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                    else
                        # Phase 3: Vertical to output level
                        plot!(plt, [start_x, pickup_x], [start_y, start_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                        plot!(plt, [pickup_x, pickup_x], [start_y, pickup_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                        plot!(plt, [pickup_x, pickup_x], [pickup_y, current_y], label="",
                             color=agv_colors[i], linewidth=3, alpha=0.7,
                             linestyle=:solid)
                    end
                end
                
                # Add axis alignment indicators
                if phase == "→ X-Axis"
                    # Show horizontal line to emphasize X-axis movement
                    plot!(plt, [start_x, current_x], [current_y, current_y],
                          label="", color=agv_colors[i], linewidth=1, 
                          linestyle=:dash, alpha=0.5)
                elseif phase == "→ Y-Axis"
                    # Show vertical line to emphasize Y-axis movement  
                    plot!(plt, [current_x, current_x], [start_y, current_y],
                          label="", color=agv_colors[i], linewidth=1,
                          linestyle=:dash, alpha=0.5)
                end
                
                # Plot pickup location (star when not reached) with storage info
                if current_distance <= total_distance_x_to_pickup + total_distance_y_to_pickup
                    scatter!(plt, [pickup_x], [pickup_y], label="",
                            color=agv_colors[i], marker=:star5, markersize=8)
                    
                    # Add storage location marker
                    storage_marker = "S$(order.id)"
                    annotate!(plt, pickup_x + 0.2, pickup_y + 0.2, 
                             text(storage_marker, agv_colors[i], :left, 7))
                end
            end
        end
# Add legend for demand and storage markers (inside animation loop)
        annotate!(plt, 0.5, WAREHOUSE_HEIGHT - 0.3, 
                 text("📦 Demand Points: Input Dock + Customer Pickup Areas", :darkgreen, :left, 10, :bold))
        annotate!(plt, 0.5, WAREHOUSE_HEIGHT - 0.6, 
                 text("🏭 Storage Zones: Red=High, Orange=Medium, Yellow=Low Frequency", :darkred, :left, 10, :bold))
    end
    
    # Save animation
    gif(anim, filename, fps=fps)
    println("✅ Enhanced animation saved to: $filename")
    println("   Duration: $(n_frames/fps) seconds at $(fps) fps")
    println("   Features: Cartesian movement + Demand/Storage markers")
    
    return filename
end

function create_demand_storage_visualization(warehouse, orders, filename="demand_storage_markers.png")
    """Create detailed visualization showing demand and storage location markers"""
    
    println("\n📍 CREATING DEMAND & STORAGE MARKERS VISUALIZATION...")
    
    plt = plot(size=(1400, 700), dpi=150, legend=:outertopright,
               xlabel="X Position (meters)", ylabel="Y Position (meters)",
               title="Warehouse Demand & Storage Location Markers",
               xlims=(0, WAREHOUSE_WIDTH), ylims=(0, WAREHOUSE_HEIGHT),
               aspect_ratio=:equal, grid=true)
    
    # Plot storage locations by zone with labels
    for zone in [:high, :medium, :low]
        zone_locs = filter(loc -> loc.zone == zone, warehouse.storage_locations)
        if !isempty(zone_locs)
            xs = [loc.position[1] * GRID_RESOLUTION for loc in zone_locs]
            ys = [loc.position[2] * GRID_RESOLUTION for loc in zone_locs]
            
            color = zone == :high ? :red :
                   zone == :medium ? :orange : :yellow
            alpha = zone == :high ? 0.6 : zone == :medium ? 0.4 : 0.3
            
            scatter!(plt, xs, ys, label="$(titlecase(string(zone))) Frequency Storage",
                    color=color, marker=:square, markersize=6, alpha=alpha)
            
            # Add sample storage location labels
            for (i, loc) in enumerate(zone_locs[1:min(3, end)])
                storage_x = loc.position[1] * GRID_RESOLUTION
                storage_y = loc.position[2] * GRID_RESOLUTION
                storage_label = "S$(loc.id):$(loc.item_type)"
                annotate!(plt, storage_x + 0.1, storage_y + 0.1, 
                         text(storage_label, color, :left, 6))
            end
        end
    end
    
    # Plot docks with demand emphasis
    input_x = warehouse.input_dock[1] * GRID_RESOLUTION
    input_y = warehouse.input_dock[2] * GRID_RESOLUTION
    output_x = warehouse.output_dock[1] * GRID_RESOLUTION
    output_y = warehouse.output_dock[2] * GRID_RESOLUTION
    
    scatter!(plt, [input_x], [input_y], label="Input Dock (Primary Demand)",
            color=:green, marker=:diamond, markersize=15, markerstrokewidth=3)
    scatter!(plt, [output_x], [output_y], label="Output Dock",
            color=:blue, marker=:diamond, markersize=15, markerstrokewidth=3)
    
    # Add multiple demand location markers around input dock
    demand_locations = [
        (input_x + 0.5, input_y + 0.5, "Demand Zone A", :lightgreen),
        (input_x + 0.5, input_y - 0.5, "Demand Zone B", :lightgreen),
        (input_x - 0.5, input_y, "Demand Zone C", :lightgreen),
        (input_x, input_y + 0.8, "Urgent Demand", :red),
        (input_x, input_y - 0.8, "Normal Demand", :orange),
    ]
    
    for (dx, dy, label, color) in demand_locations
        scatter!(plt, [dx], [dy], label="",
                color=color, marker=:triangle, markersize=10, alpha=0.8)
        annotate!(plt, dx + 0.2, dy, text(label, :black, :left, 8))
    end
    
    # Plot order pickup locations with enhanced markers
    for (i, order) in enumerate(orders)
        pickup_x = order.pickup_location[1] * GRID_RESOLUTION
        pickup_y = order.pickup_location[2] * GRID_RESOLUTION
        
        marker_color = order.priority == :urgent ? :red :
                      order.priority == :normal ? :orange : :green
        
        scatter!(plt, [pickup_x], [pickup_y],
                label="Order $(order.id) ($(order.priority))",
                color=marker_color, marker=:star, markersize=12,
                markerstrokewidth=2, alpha=0.9)
        
        # Add order information label
        order_label = "O$(order.id):$(order.total_crates)cr"
        annotate!(plt, pickup_x + 0.3, pickup_y + 0.3, 
                 text(order_label, marker_color, :left, 7))
    end
    
    # Add informative annotations
    annotate!(plt, WAREHOUSE_WIDTH - 1, WAREHOUSE_HEIGHT - 0.3, 
             text("📍 Storage Legend:", :black, :right, 12, :bold))
    annotate!(plt, WAREHOUSE_WIDTH - 1, WAREHOUSE_HEIGHT - 0.6, 
             text("• Red = High Frequency (Items A/B)", :darkred, :right, 10))
    annotate!(plt, WAREHOUSE_WIDTH - 1, WAREHOUSE_HEIGHT - 0.9, 
             text("• Orange = Medium Frequency (Item B)", :darkorange, :right, 10))
    annotate!(plt, WAREHOUSE_WIDTH - 1, WAREHOUSE_HEIGHT - 1.2, 
             text("• Yellow = Low Frequency (Item C)", :darkgoldenrod, :right, 10))
    
    annotate!(plt, 1, WAREHOUSE_HEIGHT - 0.3, 
             text("🚚 Demand Points:", :darkgreen, :left, 12, :bold))
    annotate!(plt, 1, WAREHOUSE_HEIGHT - 0.6, 
             text("• Input Dock = Primary demand source", :darkgreen, :left, 10))
    annotate!(plt, 1, WAREHOUSE_HEIGHT - 0.9, 
             text("• Demand Zones = Customer pickup areas", :darkgreen, :left, 10))
    annotate!(plt, 1, WAREHOUSE_HEIGHT - 1.2, 
             text("• Stars = Order pickup locations", :darkgreen, :left, 10))
    
    # Save visualization
    savefig(plt, filename)
    println("✅ Demand & Storage markers visualization saved to: $filename")
    
    return plt
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
    
    # 2. AGV routes with Cartesian movement
    visualize_agv_routes(warehouse, agvs, orders, assignments,
                        "agv_routes.png")
    
    # 3. Demand and Storage location markers
    create_demand_storage_visualization(warehouse, orders,
                                   "demand_storage_markers.png")
    
    # 4. Enhanced animation with Cartesian movement + markers
    create_agv_animation(warehouse, agvs, orders, assignments,
                        "agv_animation.gif")
    
    println("\n" * "=" ^ 70)
    println("✅ ENHANCED VISUALIZATION DEMO COMPLETED!")
    println("=" ^ 70)
    println("\n📁 Generated Files:")
    println("   1. warehouse_layout.png        - Static warehouse layout")
    println("   2. agv_routes.png            - AGV Cartesian routes")
    println("   3. demand_storage_markers.png  - Demand & Storage markers")
    println("   4. agv_animation.gif          - Enhanced animation with markers")
    println("\n✨ Features:")
    println("   • Cartesian movement (X-axis then Y-axis)")
    println("   • Demand location markers (Input Dock + Customer areas)")
    println("   • Storage zone markers (High/Medium/Low frequency)")
    println("   • Fixed diagonal movement issue")
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
