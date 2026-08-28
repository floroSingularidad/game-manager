extends Node3D

# Configuración editable desde el panel derecho de Godot (Inspector)
@export var grid_size: int = 7
@export var tile_size: float = 2.2
@export var tile_gap: float = 0.15
@export var tick_seconds: float = 2.2
@export var starting_money: int = 400

# Colores por dueño
var COLORS = {
	"player": Color(0.79, 0.64, 0.15),   # Dorado
	"rival": Color(0.48, 0.14, 0.14),    # Rojo
	"neutral": Color(0.23, 0.24, 0.25)   # Gris
}

# Estado del juego
var money: float = 0.0
var tiles: Array = []
var selected_tile = null
var game_over: bool = false
var tick_accum: float = 0.0

func _ready():
	money = starting_money
	build_grid()
	print("Bienvenido, jefe. El distrito espera órdenes.")

# =========================================================
# Generación del tablero 3D
# =========================================================
func build_grid():
	var offset = (grid_size - 1) * (tile_size + tile_gap) / 2.0
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(tile_size, 0.35, tile_size)

	for x in range(grid_size):
		for z in range(grid_size):
			var tile_node = MeshInstance3D.new()
			tile_node.mesh = box_mesh
			tile_node.name = "Tile_%d_%d" % [x, z]
			
			var pos_x = x * (tile_size + tile_gap) - offset
			var pos_z = z * (tile_size + tile_gap) - offset
			tile_node.position = Vector3(pos_x, 0, pos_z)
			add_child(tile_node)

			# Determinar propietario inicial
			var is_center = (x == grid_size / 2 and z == grid_size / 2)
			var is_corner = (x == 0 and z == 0) or (x == grid_size - 1 and z == grid_size - 1) or \
						   (x == 0 and z == grid_size - 1) or (x == grid_size - 1 and z == 0)

			var owner_type = "neutral"
			if is_center:
				owner_type = "player"
			elif is_corner and (x + z) % 2 == 0:
				owner_type = "rival"

			# Material con color según el dueño
			var mat = StandardMaterial3D.new()
			mat.albedo_color = COLORS[owner_type]
			mat.roughness = 0.65
			tile_node.material_override = mat

			# Guardar información del territorio
			var tile_data = {
				"x": x,
				"z": z,
				"name": "Bloque " + char(65 + x) + str(z + 1),
				"owner": owner_type,
				"value": 60 + randi() % 90,
				"income": 12 + randi() % 18,
				"defense": 5 + randi() % 15,
				"node": tile_node,
				"material": mat
			}
			tiles.append(tile_data)

func refresh_tile_color(tile_data):
	tile_data["material"].albedo_color = COLORS[tile_data["owner"]]

# =========================================================
# Ciclo económico e IA rival
# =========================================================
func _process(delta):
	if game_over:
		return
		
	tick_accum += delta
	if tick_accum >= tick_seconds:
		tick_accum = 0.0
		
		# Cobrar dinero de tus territorios
		var income = 0
		for t in tiles:
			if t["owner"] == "player":
				income += t["income"]
		money += income
		
		rival_turn()
		check_game_over()

func rival_turn():
	var rival_tiles = tiles.filter(func(t): return t["owner"] == "rival")
	if rival_tiles.is_empty():
		return
	
	var source = rival_tiles[randi() % rival_tiles.size()]
	var neighbors = get_neighbors(source)
	var neutral_neighbors = neighbors.filter(func(n): return n["owner"] == "neutral")
	
	if not neutral_neighbors.is_empty() and randf() < 0.55:
		var target = neutral_neighbors[randi() % neutral_neighbors.size()]
		target["owner"] = "rival"
		refresh_tile_color(target)
		print("La familia rival se expandió a ", target["name"])

func get_neighbors(tile_data):
	var result = []
	for n in tiles:
		if abs(n["x"] - tile_data["x"]) + abs(n["z"] - tile_data["z"]) == 1:
			result.append(n)
	return result

# =========================================================
# Acciones del jugador (Comprar / Atacar)
# =========================================================
func buy_tile(tile_data):
	if tile_data["owner"] != "neutral" or money < tile_data["value"]:
		return
	money -= tile_data["value"]
	tile_data["owner"] = "player"
	refresh_tile_color(tile_data)
	print("Adquiriste ", tile_data["name"])

func attack_tile(tile_data):
	if tile_data["owner"] != "rival":
		return
	var cost = round(tile_data["value"] * 0.6)
	if money < cost:
		return
	money -= cost

	var chance = min(0.9, float(cost) / (cost + tile_data["defense"] * 4))
	if randf() < chance:
		tile_data["owner"] = "player"
		tile_data["defense"] = max(5, round(tile_data["defense"] * 0.7))
		refresh_tile_color(tile_data)
		print("¡Éxito! Tomaste ", tile_data["name"])
	else:
		tile_data["defense"] += 4
		print("Ataque fallido en ", tile_data["name"])
	
	check_game_over()

func check_game_over():
	var total = tiles.size()
	var player_count = tiles.filter(func(t): return t["owner"] == "player").size()
	var rival_count = tiles.filter(func(t): return t["owner"] == "rival").size()

	if player_count >= ceil(total * 0.7):
		end_game(true, "Controlas el distrito entero.")
	elif player_count == 0:
		end_game(false, "Perdiste todos tus territorios.")
	elif rival_count >= ceil(total * 0.85):
		end_game(false, "La familia rival controla el distrito.")

func end_game(win: bool, text: String):
	game_over = true
	if win:
		print("¡VICTORIA! ", text)
	else:
		print("DERROTA: ", text)
