model model1

global {
	int nb_people <- 2147;
	int nb_shelters <- 10;
	float step <- 5 #mn;
	file roads_shapefile <- file("../includes/roads.shp");
	file buildings_shapefile <- file("../includes/buildings.shp");
	geometry shape <- envelope(roads_shapefile);
	graph road_network;

	// Statistics tracking
	int nb_evacuated <- 0;
	int nb_survivors <- 0;
	int nb_casualties <- 0;
	int nb_congested_roads <- 0;
	list<float> evacuation_times <- [];
	float start_time;

	// Flood simulation
	float flood_speed <- 1.0 #km/#h;
	float flood_y_position <- 0.0;
	geometry flood_area <- nil;
	bool flood_complete <- false;

	// Information dissemination (for limited_info experiment)
	bool use_limited_info <- false;
	float initial_aware_percentage <- 10.0;
	float additional_aware_percentage <- 10.0;
	int cycles_between_waves <- 1;
	int nb_aware <- 0;
	int last_wave_cycle <- 0;

	init{
		start_time <- time;
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road);		
		create building from: buildings_shapefile;
		
		list<building> sorted_buildings <- building sort_by (-each.shape.area);
		
		int i <- 1;
		ask nb_shelters first sorted_buildings {
			is_shelter <- true;
			name <- "S#" + i;
			i <- i + 1;
		}
		
		create people number:nb_people {
			location <- any_location_in(one_of(building));
			// In limited info mode, start everyone as unaware
			if use_limited_info {
				is_aware <- false;
			}
		}

		// Set initial awareness for limited info mode
		if use_limited_info {
			int nb_initial_aware <- int(nb_people * initial_aware_percentage / 100);
			ask nb_initial_aware among people {
				is_aware <- true;
			}
			nb_aware <- nb_initial_aware;
			last_wave_cycle <- 0;
		}
	}
	reflex spread_information when: use_limited_info {
		// Check if it's time for a new wave of awareness
		if (cycle - last_wave_cycle >= cycles_between_waves) and (nb_aware < nb_people) {
			list<people> unaware_people <- people where (!each.is_aware);
			if !empty(unaware_people) {
				int nb_to_inform <- int(nb_people * additional_aware_percentage / 100);
				int nb_can_inform <- min(nb_to_inform, length(unaware_people));
				ask nb_can_inform among unaware_people {
					is_aware <- true;
				}
				nb_aware <- nb_aware + nb_can_inform;
				last_wave_cycle <- cycle;
			}
		}
	}

	reflex update_road_traffic {
		ask road { people_on_road <- 0; }
		ask people {
			if current_edge != nil {
				road(current_edge).people_on_road <- road(current_edge).people_on_road + 1;
			}
		}
		// Count congested roads
		nb_congested_roads <- road count (each.people_on_road > each.capacity);
	}

	reflex update_flood {
		// Advance flood position at specified speed
		flood_y_position <- flood_y_position + (flood_speed * step);

		// Create flood area from Y=0 to current flood position
		if flood_y_position <= shape.height {
			flood_area <- rectangle(shape.width, flood_y_position) at_location {shape.location.x, flood_y_position / 2};
		} else {
			flood_area <- shape;
			flood_complete <- true;
		}
	}

	reflex stop_simulation when: empty(people) or flood_complete {
		do pause;
	}
}

species people skills:[moving]{
	float max_speed <- (2 + rnd(3)) #km/#h;
	float speed <- max_speed;
	float person_start_time;
	bool is_aware <- true; // Default true for normal mode, set in init for limited info mode

	building target_shelter;

	init {
		target_shelter <- building where (each.is_shelter) closest_to self;
		person_start_time <- time;
	}

	reflex detect_nearby_flood when: !is_aware {
		// People become aware if flood is within 200m
		if flood_area != nil and (location.y - flood_y_position < 200) {
			is_aware <- true;
			nb_aware <- nb_aware + 1;
		}
	}

	reflex move when: is_aware {
		do goto target: target_shelter on: road_network;

		if (location = target_shelter.location) {
			target_shelter.people_count <- target_shelter.people_count + 1;
			nb_evacuated <- nb_evacuated + 1;
			nb_survivors <- nb_survivors + 1;
			float evacuation_time <- (time - person_start_time) / #mn;
			add evacuation_time to: evacuation_times;
			do die;
		}

		if current_edge != nil {
			road current_road <- road(current_edge);
			if current_road.people_on_road > current_road.capacity {
				speed <- max_speed / 2.0;
			} else {
				speed <- max_speed;
			}
		}
	}

	reflex check_flood_casualty {
		if flood_area != nil and flood_area covers location {
			nb_casualties <- nb_casualties + 1;
			do die;
		}
	}


	
	aspect circle {
		rgb person_color <- #green;

		// Unaware people are gray
		if !is_aware {
			person_color <- #gray;
		} else if flood_area != nil {
			// Aware people: orange if close to flood, green otherwise
			float distance_to_flood <- location.y - flood_y_position;
			if distance_to_flood < 100 {
				person_color <- #orange;
			}
		}
		draw circle(10) color: person_color;
	}
	

	
}

species road {
	float capacity <- 1 + shape.perimeter / 30;
	int people_on_road <- 0;
	
	aspect geom {
		draw shape width: capacity color: (people_on_road > capacity) ? #red : #black;
	}

}

species building {
	bool is_shelter <- false;
	string name;
	int people_count <- 0;
	
	aspect geom {
		draw shape color: is_shelter ? #blue : #gray;
	}

}

experiment main type: gui {
	parameter "Number of shelters" var: nb_shelters min: 1 max: 100;
	parameter "Flood speed (km/h)" var: flood_speed min: 0.1 max: 10.0 step: 0.1;

	output {
		// Real-time Monitors
		monitor "Survivors" value: string(nb_survivors) + " (" + string(with_precision((nb_survivors / nb_people) * 100, 1)) + "%)" refresh: every(1 #cycles);
		monitor "Casualties" value: string(nb_casualties) + " (" + string(with_precision((nb_casualties / nb_people) * 100, 1)) + "%)" refresh: every(1 #cycles);
		monitor "Still Evacuating" value: string(length(people)) + " (" + string(with_precision((length(people) / nb_people) * 100, 1)) + "%)" refresh: every(1 #cycles);
		monitor "Elapsed Time" value: string(with_precision((time - start_time) / #mn, 1)) + " minutes" refresh: every(1 #cycles);
		monitor "Congested Roads" value: string(nb_congested_roads) + " roads over capacity" refresh: every(1 #cycles);
		monitor "Flood Progress" value: string(with_precision((flood_y_position / shape.height) * 100, 1)) + "% - " + string(with_precision(flood_y_position, 0)) + "m" refresh: every(1 #cycles);

		display map type: 2d {
			species road aspect:geom;
			species building aspect:geom;
			species people aspect:circle;
			graphics "flood" {
				if flood_area != nil {
					draw flood_area color: rgb(0, 0, 255, 0.1) border: rgb(0, 0, 255, 0.3);
				}
			}
		}

		display shelter_occupancy type: 2d refresh: every(10 #cycles) {
			chart "People in Shelters" type: histogram {
				datalist legend: (building where each.is_shelter) collect each.name value: (building where each.is_shelter) collect each.people_count;
			}
		}

		display evacuation_progress type: 2d refresh: every(10 #cycles) {
			chart "Evacuation Rate Over Time" type: series x_label: "Time (minutes)" y_label: "People Evacuated" {
				data "Evacuated" value: nb_evacuated color: #green;
			}
		}

		display congestion_chart type: 2d refresh: every(10 #cycles) {
			chart "Road Congestion Over Time" type: series x_label: "Time (minutes)" y_label: "Congested Roads" {
				data "Congested Roads" value: nb_congested_roads color: #red;
			}
		}

		display evacuation_outcome type: 2d refresh: every(10 #cycles) {
			chart "Evacuation Outcome" type: pie {
				data "Survivors" value: nb_survivors color: #green;
				data "Casualties" value: nb_casualties color: #red;
				data "Still Evacuating" value: length(people) color: #orange;
			}
		}
	}
}

experiment limited_info type: gui {
	parameter "Number of shelters" var: nb_shelters min: 1 max: 100;
	parameter "Flood speed (km/h)" var: flood_speed min: 0.1 max: 10.0 step: 0.1;
	parameter "Initial aware (%)" var: initial_aware_percentage min: 0.0 max: 100.0 step: 1.0;
	parameter "Additional aware per wave (%)" var: additional_aware_percentage min: 0.0 max: 100.0 step: 1.0;
	parameter "Cycles between waves" var: cycles_between_waves min: 1 max: 20;

	init {
		use_limited_info <- true;
	}

	output {
		// Real-time Monitors
		monitor "Aware" value: string(nb_aware) + " (" + string(with_precision((nb_aware / nb_people) * 100, 1)) + "%)" refresh: every(1 #cycles);
		monitor "Unaware" value: string(nb_people - nb_aware - nb_evacuated - nb_casualties) + " (" + string(with_precision(((nb_people - nb_aware - nb_evacuated - nb_casualties) / nb_people) * 100, 1)) + "%)" refresh: every(1 #cycles);
		monitor "Survivors" value: string(nb_survivors) + " (" + string(with_precision((nb_survivors / nb_people) * 100, 1)) + "%)" refresh: every(1 #cycles);
		monitor "Casualties" value: string(nb_casualties) + " (" + string(with_precision((nb_casualties / nb_people) * 100, 1)) + "%)" refresh: every(1 #cycles);
		monitor "Still Evacuating" value: string(length(people where each.is_aware)) + " (" + string(with_precision((length(people where each.is_aware) / nb_people) * 100, 1)) + "%)" refresh: every(1 #cycles);
		monitor "Elapsed Time" value: string(with_precision((time - start_time) / #mn, 1)) + " minutes" refresh: every(1 #cycles);
		monitor "Congested Roads" value: string(nb_congested_roads) + " roads over capacity" refresh: every(1 #cycles);
		monitor "Flood Progress" value: string(with_precision((flood_y_position / shape.height) * 100, 1)) + "% - " + string(with_precision(flood_y_position, 0)) + "m" refresh: every(1 #cycles);

		display map type: 2d {
			species road aspect:geom;
			species building aspect:geom;
			species people aspect:circle;
			graphics "flood" {
				if flood_area != nil {
					draw flood_area color: rgb(0, 0, 255, 0.1) border: rgb(0, 0, 255, 0.3);
				}
			}
		}

		display shelter_occupancy type: 2d refresh: every(10 #cycles) {
			chart "People in Shelters" type: histogram {
				datalist legend: (building where each.is_shelter) collect each.name value: (building where each.is_shelter) collect each.people_count;
			}
		}

		display awareness_spread type: 2d refresh: every(10 #cycles) {
			chart "Information Dissemination" type: series x_label: "Time (minutes)" y_label: "Number of People" {
				data "Aware" value: nb_aware color: #blue;
				data "Survivors" value: nb_survivors color: #green;
				data "Casualties" value: nb_casualties color: #red;
			}
		}

		display evacuation_progress type: 2d refresh: every(10 #cycles) {
			chart "Evacuation Rate Over Time" type: series x_label: "Time (minutes)" y_label: "People Evacuated" {
				data "Evacuated" value: nb_evacuated color: #green;
			}
		}

		display congestion_chart type: 2d refresh: every(10 #cycles) {
			chart "Road Congestion Over Time" type: series x_label: "Time (minutes)" y_label: "Congested Roads" {
				data "Congested Roads" value: nb_congested_roads color: #red;
			}
		}

		display evacuation_outcome type: 2d refresh: every(10 #cycles) {
			chart "Evacuation Outcome" type: pie {
				data "Survivors" value: nb_survivors color: #green;
				data "Casualties" value: nb_casualties color: #red;
				data "Aware & Evacuating" value: length(people where each.is_aware) color: #orange;
				data "Unaware" value: length(people where (!each.is_aware)) color: #gray;
			}
		}
	}
}


