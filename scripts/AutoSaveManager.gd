extends Node

# Gerenciador de Salvamento Automático
# Garante que os dados do jogador sejam salvos periodicamente

var auto_save_timer: Timer
var save_interval: float = 30.0  # Salva a cada 30 segundos
var is_auto_save_enabled: bool = true
var last_save_time: float = 0.0

func _ready():
	print("💾 Iniciando Gerenciador de Salvamento Automático...")
	setup_auto_save_timer()
	
	# Conecta aos sinais do Global para salvar quando dados mudarem
	if Global.has_signal("player_data_updated"):
		Global.connect("player_data_updated", _on_player_data_changed)

func setup_auto_save_timer():
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = save_interval
	auto_save_timer.timeout.connect(_on_auto_save_timeout)
	auto_save_timer.autostart = true
	add_child(auto_save_timer)
	
	print("⏰ Timer de salvamento automático configurado (%.1fs)" % save_interval)

func _on_auto_save_timeout():
	if is_auto_save_enabled:
		perform_auto_save()

func _on_player_data_changed():
	# Salva imediatamente quando dados importantes mudam
	var current_time = Time.get_unix_time_from_system()
	
	# Evita salvamentos muito frequentes (mínimo 5 segundos entre salvamentos)
	if current_time - last_save_time >= 5.0:
		perform_auto_save()

func perform_auto_save():
	print("💾 Executando salvamento automático...")
	last_save_time = Time.get_unix_time_from_system()
	
	# Sempre salva localmente
	Global.save_local_data()
	
	# Tenta salvar no Firebase se estiver online
	if Global.is_online and not Global.player_id.is_empty():
		Global.save_player_data_to_firebase()
		print("✅ Salvamento automático: Local + Firebase")
	else:
		print("✅ Salvamento automático: Apenas local (Firebase offline)")

func enable_auto_save():
	is_auto_save_enabled = true
	auto_save_timer.start()
	print("🟢 Salvamento automático habilitado")

func disable_auto_save():
	is_auto_save_enabled = false
	auto_save_timer.stop()
	print("🔴 Salvamento automático desabilitado")

func force_save():
	print("🚀 Forçando salvamento imediato...")
	perform_auto_save()

func set_save_interval(new_interval: float):
	save_interval = new_interval
	auto_save_timer.wait_time = new_interval
	print("⏰ Intervalo de salvamento alterado para %.1fs" % new_interval)

# Função chamada ao sair do jogo
func _exit_tree():
	print("🚪 AutoSaveManager sendo finalizado - salvamento final...")
	perform_auto_save()
