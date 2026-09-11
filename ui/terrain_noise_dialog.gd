@tool
class_name TerrainNoiseDialog
extends ConfirmationDialog

## Dialog for generating procedural heightfields using FastNoiseLite.

signal generate_noise_requested(noise: FastNoiseLite, amplitude: float, flatten_edges: bool)

@onready var noise_type_option: OptionButton = %NoiseTypeOption
@onready var frequency_spin: SpinBox = %FrequencySpin
@onready var amplitude_spin: SpinBox = %AmplitudeSpin
@onready var octaves_spin: SpinBox = %OctavesSpin
@onready var seed_spin: SpinBox = %SeedSpin
@onready var flatten_edges_check: CheckBox = %FlattenEdgesCheck


func _ready() -> void:
	confirmed.connect(_on_confirmed)
	_setup_options()


func _setup_options() -> void:
	if noise_type_option.item_count == 0:
		noise_type_option.add_item("Simplex Smooth", FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
		noise_type_option.add_item("Perlin", FastNoiseLite.TYPE_PERLIN)
		noise_type_option.add_item("Cellular / Worley", FastNoiseLite.TYPE_CELLULAR)
		noise_type_option.add_item("Simplex", FastNoiseLite.TYPE_SIMPLEX)
		noise_type_option.add_item("Value", FastNoiseLite.TYPE_VALUE)


func open_dialog() -> void:
	popup_centered(Vector2i(380, 320))


func _on_confirmed() -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = noise_type_option.get_selected_id() as FastNoiseLite.NoiseType
	noise.frequency = float(frequency_spin.value)
	noise.fractal_octaves = int(octaves_spin.value)
	noise.seed = int(seed_spin.value)

	var amp: float = float(amplitude_spin.value)
	var flatten_edges: bool = flatten_edges_check.button_pressed

	generate_noise_requested.emit(noise, amp, flatten_edges)
