"""
KPI (Key Performance Indicator) tracking system for warehouse optimization
Primary KPIs: AGV idle time, AGV utilization, on-time delivery rate
"""

using DataFrames, Statistics

"""
    WarehouseKPIs

Core KPI structure for warehouse performance monitoring
"""
struct WarehouseKPIs
    # AGV Performance KPIs
    agv_idle_time::Float64           # Percentage of total time AGVs are idle
    utilized_agvs::Int               # Number of AGVs currently utilized
    utilization_rate::Float64         # Percentage of AGV fleet utilization
    
    # Order Performance KPIs  
    on_time_delivery::Float64         # Percentage of orders delivered on time
    total_orders::Int                # Total number of orders processed
    completed_orders::Int            # Number of completed orders
    late_orders::Int                 # Number of late orders
    
    # Efficiency KPIs
    average_completion_time::Float64  # Average time to complete orders (minutes)
    total_distance_traveled::Float64  # Total distance all AGVs traveled (meters)
    orders_per_hour::Float64         # Throughput metric
    energy_efficiency::Float64       # Distance per order efficiency
    
    # Time and Performance
    total_simulation_time::Float64   # Total simulation time (minutes)
    shift_performance::Dict{Int, Float64}  # Performance by shift
end

"""
    KPIHistory

Historical KPI tracking for trend analysis
"""
mutable struct KPIHistory
    timestamps::Vector{Float64}
    idle_times::Vector{Float64}
    utilization_rates::Vector{Float64}
    on_time_rates::Vector{Float64}
    throughputs::Vector{Float64}
    shift_data::Dict{Int, Vector{Float64}}  # KPIs by shift
end

"""
    create_kpi_history()

Initialize KPI history tracking
"""
function create_kpi_history()
    return KPIHistory(
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Float64[],
        Dict(1 => Float64[], 2 => Float64[])
    )
end

"""
    calculate_agv_kpis(agvs::Vector{AGV}, total_time::Float64)

Calculate AGV-specific KPIs
"""
function calculate_agv_kpis(agvs::Vector{AGV}, total_time::Float64)
    # AGV idle time calculation
    total_idle_time = sum(agv.idle_time for agv in agvs)
    agv_idle_time = total_time > 0 ? total_idle_time / (length(agvs) * total_time) : 0.0
    
    # AGV utilization calculation  
    utilized_agvs = count(agv -> agv.state != IDLE && agv.state != CHARGING, agvs)
    utilization_rate = total_time > 0 ? (sum(agv -> get_agv_utilization_rate(agv, total_time), agvs) / length(agvs)) : 0.0
    
    return agv_idle_time, utilized_agvs, utilization_rate
end

"""
    calculate_order_kpis(orders::Vector{Order}, current_time::Float64)

Calculate order-specific KPIs
"""
function calculate_order_kpis(orders::Vector{Order}, current_time::Float64)
    total_orders = length(orders)
    completed_orders = count(order -> order.status == :completed, orders)
    late_orders = count(order -> order.status == :late, orders)
    
    # On-time delivery calculation
    if completed_orders + late_orders > 0
        on_time_delivery = completed_orders / (completed_orders + late_orders)
    else
        on_time_delivery = 0.0
    end
    
    # Average completion time
    completion_times = Float64[]
    for order in orders
        if order.completion_time !== nothing
            completion_time = order.completion_time - order.creation_time
            push!(completion_times, completion_time)
        end
    end
    
    average_completion_time = length(completion_times) > 0 ? 
        mean(completion_times) : 0.0
    
    return on_time_delivery, total_orders, completed_orders, late_orders, average_completion_time
end

"""
    calculate_efficiency_kpis(agvs::Vector{AGV}, orders::Vector{Order}, total_time::Float64)

Calculate efficiency and performance metrics
"""
function calculate_efficiency_kpis(agvs::Vector{AGV}, orders::Vector{Order}, total_time::Float64)
    # Total distance traveled
    total_distance = sum(agv.total_distance_traveled for agv in agvs)
    
    # Orders per hour (throughput)
    completed_orders = count(order -> order.status == :completed, orders)
    orders_per_hour = total_time > 0 ? (completed_orders / total_time) * 60 : 0.0
    
    # Energy efficiency (distance per order)
    if completed_orders > 0
        energy_efficiency = total_distance / completed_orders
    else
        energy_efficiency = 0.0
    end
    
    return total_distance, orders_per_hour, energy_efficiency
end

"""
    calculate_shift_kpis(orders::Vector{Order}, current_time::Float64)

Calculate performance by shift
"""
function calculate_shift_kpis(orders::Vector{Order}, current_time::Float64)
    shift_performance = Dict{Int, Float64}()
    
    # Calculate which shift each order belongs to
    shift_1_orders = Order[]
    shift_2_orders = Order[]
    
    for order in orders
        # Simple shift calculation based on creation time
        hours_from_start = order.creation_time / 60
        shift_num = ((Int(floor(hours_from_start)) % 24) ÷ 12) + 1
        
        if shift_num == 1
            push!(shift_1_orders, order)
        else
            push!(shift_2_orders, order)
        end
    end
    
    # Calculate on-time delivery for each shift
    for (shift_num, shift_orders) in [(1, shift_1_orders), (2, shift_2_orders)]
        completed = count(order -> order.status == :completed, shift_orders)
        late = count(order -> order.status == :late, shift_orders)
        
        if completed + late > 0
            shift_performance[shift_num] = completed / (completed + late)
        else
            shift_performance[shift_num] = 0.0
        end
    end
    
    return shift_performance
end

"""
    calculate_warehouse_kpis(agvs::Vector{AGV}, orders::Vector{Order}, 
                           current_time::Float64, history::KPIHistory)

Calculate comprehensive warehouse KPIs
"""
function calculate_warehouse_kpis(agvs::Vector{AGV}, orders::Vector{Order}, 
                                 current_time::Float64, history::KPIHistory)
    
    # Calculate individual KPI components
    agv_idle_time, utilized_agvs, utilization_rate = calculate_agv_kpis(agvs, current_time)
    on_time_delivery, total_orders, completed_orders, late_orders, average_completion_time = 
        calculate_order_kpis(orders, current_time)
    total_distance, orders_per_hour, energy_efficiency = calculate_efficiency_kpis(agvs, orders, current_time)
    shift_performance = calculate_shift_kpis(orders, current_time)
    
    # Create KPIs structure
    kpis = WarehouseKPIs(
        agv_idle_time,
        utilized_agvs,
        utilization_rate,
        on_time_delivery,
        total_orders,
        completed_orders,
        late_orders,
        average_completion_time,
        total_distance,
        orders_per_hour,
        energy_efficiency,
        current_time,
        shift_performance
    )
    
    # Update history
    push!(history.timestamps, current_time)
    push!(history.idle_times, agv_idle_time)
    push!(history.utilization_rates, utilization_rate)
    push!(history.on_time_rates, on_time_delivery)
    push!(history.throughputs, orders_per_hour)
    
    # Update shift-specific history
    for (shift_num, performance) in shift_performance
        if haskey(history.shift_data, shift_num)
            push!(history.shift_data[shift_num], performance)
        end
    end
    
    return kpis
end

"""
    calculate_kpi_score(kpis::WarehouseKPIs, weights::Dict{Symbol, Float64})

Calculate overall KPI score with weighted components
"""
function calculate_kpi_score(kpis::WarehouseKPIs, weights::Dict{Symbol, Float64})
    # Default weights if not provided
    default_weights = Dict(
        :idle_time => 0.30,        # Weight for idle time (lower is better)
        :utilization => 0.40,       # Weight for utilization (higher is better)
        :on_time_delivery => 0.30    # Weight for on-time delivery (higher is better)
    )
    
    final_weights = merge(default_weights, weights)
    
    # Normalize KPIs to 0-1 scale (higher is better for all)
    idle_score = 1.0 - min(kpis.agv_idle_time, 1.0)  # Convert idle time to score
    utilization_score = kpis.utilization_rate
    delivery_score = kpis.on_time_delivery
    
    # Calculate weighted score
    total_score = (final_weights[:idle_time] * idle_score + 
                   final_weights[:utilization] * utilization_score + 
                   final_weights[:on_time_delivery] * delivery_score)
    
    return total_score, (idle_score, utilization_score, delivery_score)
end

"""
    generate_kpi_report(kpis::WarehouseKPIs, target_kpis::WarehouseKPIs)

Generate detailed KPI report with target comparisons
"""
function generate_kpi_report(kpis::WarehouseKPIs, target_kpis::WarehouseKPIs)
    report = """
    ===== WAREHOUSE KPI REPORT =====
    
    AGV Performance:
    - Idle Time: $(round(kpis.agv_idle_time * 100, digits=1))% (Target: $(round(target_kpis.agv_idle_time * 100, digits=1))%)
    - Utilized AGVs: $(kpis.utilized_agvs)/5 ($(round(kpis.utilization_rate * 100, digits=1))%) (Target: $(round(target_kpis.utilization_rate * 100, digits=1))%)
    
    Order Performance:
    - On-Time Delivery: $(round(kpis.on_time_delivery * 100, digits=1))% (Target: $(round(target_kpis.on_time_delivery * 100, digits=1))%)
    - Total Orders: $(kpis.total_orders)
    - Completed Orders: $(kpis.completed_orders)
    - Late Orders: $(kpis.late_orders)
    - Average Completion Time: $(round(kpis.average_completion_time, digits=1)) minutes
    
    Efficiency Metrics:
    - Orders per Hour: $(round(kpis.orders_per_hour, digits=1))
    - Total Distance Traveled: $(round(kpis.total_distance, digits=1)) meters
    - Energy Efficiency: $(round(kpis.energy_efficiency, digits=2)) meters per order
    
    Shift Performance:
    """
    
    for (shift_num, performance) in kpis.shift_performance
        report *= "    - Shift $shift_num: $(round(performance * 100, digits=1))% on-time\n"
    end
    
    report *= "\nSimulation Time: $(round(kpis.total_simulation_time / 60, digits=1)) hours\n"
    
    return report
end

"""
    create_target_kpis()

Create target KPIs based on operational goals
"""
function create_target_kpis()
    return WarehouseKPIs(
        TARGET_IDLE_TIME,        # 10% idle time target
        4,                       # Target 4 out of 5 AGVs utilized
        TARGET_UTILIZATION,      # 80% utilization target
        TARGET_ON_TIME_DELIVERY, # 95% on-time delivery target
        0, 0, 0,                # Order counts (not applicable for targets)
        25.0,                    # 25 minutes average completion time
        0, 0, 0,                # Efficiency metrics (not applicable for targets)
        0,                       # Simulation time (not applicable)
        Dict(1 => 0.95, 2 => 0.95)  # Shift performance targets
    )
end

"""
    detect_kpi_trends(history::KPIHistory, window_size::Int = 10)

Analyze KPI trends over time
"""
function detect_kpi_trends(history::KPIHistory, window_size::Int = 10)
    if length(history.timestamps) < window_size
        return Dict(
            :idle_trend => :stable,
            :utilization_trend => :stable,
            :delivery_trend => :stable
        )
    end
    
    # Calculate trends using linear regression on recent data
    recent_idle = history.idle_times[end-window_size+1:end]
    recent_util = history.utilization_rates[end-window_size+1:end]
    recent_delivery = history.on_time_rates[end-window_size+1:end]
    
    function calculate_trend(data::Vector{Float64})
        if length(data) < 2
            return 0.0
        end
        
        x = 1:length(data)
        n = length(data)
        sum_x = sum(x)
        sum_y = sum(data)
        sum_xy = sum(x .* data)
        sum_x2 = sum(x.^2)
        
        slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x^2)
        return slope
    end
    
    idle_slope = calculate_trend(recent_idle)
    util_slope = calculate_trend(recent_util)
    delivery_slope = calculate_trend(recent_delivery)
    
    # Classify trends
    function classify_trend(slope::Float64)
        if abs(slope) < 0.001
            return :stable
        elseif slope > 0
            return :improving
        else
            return :declining
        end
    end
    
    return Dict(
        :idle_trend => classify_trend(-idle_slope),  # Negative slope is good for idle time
        :utilization_trend => classify_trend(util_slope),
        :delivery_trend => classify_trend(delivery_slope)
    )
end