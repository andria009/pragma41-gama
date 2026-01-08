model model1

global {
	int nb_people <- 2147;
	int nb_shelters <- 10;
	float step <- 5 #mn;
	file roads_shapefile <- file("../includes/roads.shp");
	file buildings_shapefile <- file("../includes/buildings.shp");
	geometry shape <- envelope(roads_shapefile);	
	graph road_network;
	
	
	init{
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road);		
		create building from: buildings_shapefile;
		
		list<building> sorted_buildings <- building sort_by (-each.shape.area);
		
		int i <- 1;
		ask nb_shelters first sorted_buildings {
			is_shelter <- true;
			name <- "Shelter " + i;
			i <- i + 1;
		}
		
		create people number:nb_people {
			location <- any_location_in(one_of(building));				
		}

	}
	reflex update_road_traffic {
		ask road { people_on_road <- 0; }
		ask people {
			if current_edge != nil {
				road(current_edge).people_on_road <- road(current_edge).people_on_road + 1;
			}
		}
	}
}

species people skills:[moving]{		
	float max_speed <- (2 + rnd(3)) #km/#h;
	float speed <- max_speed;

	building target_shelter;
	
	init { 
		target_shelter <- building where (each.is_shelter) closest_to self;
	}

	reflex move {
		do goto target: target_shelter on: road_network;
		
		if (location = target_shelter.location) {
			target_shelter.people_count <- target_shelter.people_count + 1;
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


	
	aspect circle {
		draw circle(10) color: #green;
	}
	
	aspect geom3D {
		draw obj_file("../includes/people.obj", 90::{-1,0,0}) size: 5
		at: location + {0,0,7} rotate: heading - 90 color: #green;
	}
	
}

species road {
	float capacity <- 1 + shape.perimeter / 30;
	int people_on_road <- 0;
	
	aspect geom {
		draw shape color: (people_on_road > capacity) ? #red : #black width: capacity;
	}
	aspect geom3D {
		draw line(shape.points, 2.0) color: #black;
	}
}

species building {
	bool is_shelter <- false;
	string name;
	int people_count <- 0;
	
	aspect geom {
		draw shape color: is_shelter ? #blue : #gray;
	}
	aspect geom3D {
		draw shape depth: 20 #m border: #black texture:["../includes/roof_top.jpg","../includes/texture.jpg"];
	}
}

experiment main type: gui {
	parameter "Number of shelters" var: nb_shelters min: 1 max: 100;

	output {

		
		display map {
			species road aspect:geom;
			species building aspect:geom;
			species people aspect:circle;			
		}
		
		
		


		display chart_display refresh: every(10 #cycles) {
			chart "People in shelters" type: histogram {
				datalist legend: (building where each.is_shelter) collect each.name value: (building where each.is_shelter) collect each.people_count;
			}
		}

		display view3D type: 3d antialias: false {
			light #ambient intensity: 80;
			image "../includes/luneray.jpg" refresh: false; 
			species building aspect: geom3D refresh: false;
			species road aspect: geom3D refresh: false;
			species people aspect: geom3D; 
		}
	}
}


