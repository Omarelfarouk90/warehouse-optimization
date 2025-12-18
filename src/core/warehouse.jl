"""
Warehouse layout configuration for V-shaped 10m × 5m warehouse with 200 storage locations
Optimized for 24/7 2-shift operation with variable demand patterns
"""

# Warehouse dimensions (meters)
const WAREHOUSE_WIDTH = 10.0
const WAREHOUSE_HEIGHT = 5.0
const GRID_RESOLUTION = 0.25  # 25cm grid cells for precise positioning

# Grid dimensions
const GRID_WIDTH = Int(WAREHOUSE_WIDTH / GRID_RESOLUTION)
const GRID_HEIGHT = Int(WAREHOUSE_HEIGHT / GRID_RESOLUTION)

# Storage location configuration
const TOTAL_STORAGE_LOCATIONS = 200
const STORAGE_CAPACITY_KG = 5.0  # kg per storage location

# V-shaped layout zones
const HIGH_FREQ_ZONES = 80    # Near input/output (high-demand items)
const MED_FREQ_ZONES = 80     # Middle sections (medium-demand items)
const LOW_FREQ_ZONES = 40     # Far sections (low-demand items)

# Dock positions (grid coordinates)
const INPUT_DOCK_POS = (2, Int(GRID_HEIGHT/2))      # Left side
const OUTPUT_DOCK_POS = (Int(GRID_WIDTH)-2, Int(GRID_HEIGHT/2))  # Right side

# AGV safety parameters
const SAFETY_DISTANCE = 2  # grid cells (0.5m)
const AGV_SIZE = 1  # grid cell (0.25m)

# Shift configuration
const SHIFTS_PER_DAY = 2
const HOURS_PER_SHIFT = 12
const SHIFT_HANDOFF_MINUTES = 15

# KPI Targets
const TARGET_IDLE_TIME = 0.10      # 10%
const TARGET_UTILIZATION = 0.80     # 80%
const TARGET_ON_TIME_DELIVERY = 0.95  # 95%

"""
    StorageLocation

Represents a single storage location in the warehouse
"""
struct StorageLocation
    id::Int
    position::Tuple{Int, Int}  # Grid coordinates
    zone::Symbol               # :high, :medium, :low frequency
    capacity::Float64          # kg
    current_load::Float64       # kg
    item_type::Symbol          # :A, :B, :C classification
end

"""
    Warehouse

Main warehouse configuration with V-shaped layout
"""
struct Warehouse
    dimensions::Tuple{Float64, Float64}  # (width, height) in meters
    grid_size::Tuple{Int, Int}          # (width, height) in grid cells
    storage_locations::Vector{StorageLocation}
    input_dock::Tuple{Int, Int}
    output_dock::Tuple{Int, Int}
    agv_charging_stations::Vector{Tuple{Int, Int}}
end

"""
    create_v_shaped_layout()

Generate V-shaped storage location layout optimized for efficiency
"""
function create_v_shaped_layout()
    storage_locations = StorageLocation[]
    location_id = 1
    
    # Calculate V-shaped layout parameters
    center_y = Int(GRID_HEIGHT / 2)
    left_branch_start = 5
    right_branch_end = GRID_WIDTH - 5
    
    # High frequency zones - near input/output
    for i in 1:HIGH_FREQ_ZONES÷2
        # Left branch (near input)
        x = left_branch_start + i ÷ 3
        y_offset = (i % 3) - 1  # Spread vertically
        pos = (x, center_y + y_offset)
        
        item_type = i <= 20 ? :A : :B
        zone = :high
        
        push!(storage_locations, StorageLocation(
            location_id, pos, zone, STORAGE_CAPACITY_KG, 0.0, item_type
        ))
        location_id += 1
    end
    
    for i in 1:HIGH_FREQ_ZONES÷2
        # Right branch (near output)
        x = right_branch_end - i ÷ 3
        y_offset = (i % 3) - 1
        pos = (x, center_y + y_offset)
        
        item_type = i <= 20 ? :A : :B
        zone = :high
        
        push!(storage_locations, StorageLocation(
            location_id, pos, zone, STORAGE_CAPACITY_KG, 0.0, item_type
        ))
        location_id += 1
    end
    
    # Medium frequency zones - middle sections
    for i in 1:MED_FREQ_ZONES÷2
        # Left branch middle
        x = left_branch_start + 10 + i ÷ 2
        y_offset = ((i - 1) % 5) - 2
        pos = (x, center_y + y_offset)
        
        item_type = :B
        zone = :medium
        
        push!(storage_locations, StorageLocation(
            location_id, pos, zone, STORAGE_CAPACITY_KG, 0.0, item_type
        ))
        location_id += 1
    end
    
    for i in 1:MED_FREQ_ZONES÷2
        # Right branch middle
        x = right_branch_end - 10 - i ÷ 2
        y_offset = ((i - 1) % 5) - 2
        pos = (x, center_y + y_offset)
        
        item_type = :B
        zone = :medium
        
        push!(storage_locations, StorageLocation(
            location_id, pos, zone, STORAGE_CAPACITY_KG, 0.0, item_type
        ))
        location_id += 1
    end
    
    # Low frequency zones - far sections
    v_center_x = Int(GRID_WIDTH / 2)
    for i in 1:LOW_FREQ_ZONES
        # V-shaped center section
        if i <= LOW_FREQ_ZONES ÷ 2
            x = v_center_x - 2 - i ÷ 3
            y = center_y - 2 - ((i - 1) % 3)
        else
            x = v_center_x + 2 + ((i - LOW_FREQ_ZONES ÷ 2) ÷ 3)
            y = center_y - 2 - (((i - LOW_FREQ_ZONES ÷ 2) - 1) % 3)
        end
        
        pos = (x, y)
        item_type = :C
        zone = :low
        
        push!(storage_locations, StorageLocation(
            location_id, pos, zone, STORAGE_CAPACITY_KG, 0.0, item_type
        ))
        location_id += 1
    end
    
    return storage_locations
end

"""
    create_warehouse()

Create and return the complete warehouse configuration
"""
function create_warehouse()
    storage_locations = create_v_shaped_layout()
    
    # AGV charging stations near docks
    charging_stations = [
        (INPUT_DOCK_POS[1] + 1, INPUT_DOCK_POS[2]),
        (OUTPUT_DOCK_POS[1] - 1, OUTPUT_DOCK_POS[2])
    ]
    
    return Warehouse(
        (WAREHOUSE_WIDTH, WAREHOUSE_HEIGHT),
        (GRID_WIDTH, GRID_HEIGHT),
        storage_locations,
        INPUT_DOCK_POS,
        OUTPUT_DOCK_POS,
        charging_stations
    )
end

"""
    calculate_distance(pos1, pos2)

Calculate Manhattan distance between two grid positions
"""
function calculate_distance(pos1::Tuple{Int, Int}, pos2::Tuple{Int, Int})
    return abs(pos1[1] - pos2[1]) + abs(pos1[2] - pos2[2])
end

"""
    calculate_euclidean_distance(pos1, pos2)

Calculate Euclidean distance between two positions (for collision detection)
"""
function calculate_euclidean_distance(pos1::Tuple{Float64, Float64}, pos2::Tuple{Float64, Float64})
    return sqrt((pos1[1] - pos2[1])^2 + (pos1[2] - pos2[2])^2)
end

"""
    find_nearest_storage(warehouse, item_type, capacity_needed)

Find nearest storage location for given item type and capacity
"""
function find_nearest_storage(warehouse::Warehouse, item_type::Symbol, capacity_needed::Float64)
    suitable_locations = filter(loc -> 
        loc.item_type == item_type && 
        (loc.capacity - loc.current_load) >= capacity_needed,
        warehouse.storage_locations
    )
    
    if isempty(suitable_locations)
        return nothing
    end
    
    # Find nearest to input dock
    input_dock = warehouse.input_dock
    nearest_loc = reduce(suitable_locations) do a, b
        dist_a = calculate_distance(input_dock, a.position)
        dist_b = calculate_distance(input_dock, b.position)
        dist_a < dist_b ? a : b
    end
    
    return nearest_loc
end