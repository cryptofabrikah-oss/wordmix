extends Node

# Script para verificar se os dados foram salvos no Firebase

func _ready():
	print("🔍 Verificando dados no Firebase Realtime Database...")
	await get_tree().create_timer(1.0).timeout
	verify_firebase_data()

func verify_firebase_data():
	if not Global.is_online:
		print("❌ Firebase offline - não é possível verificar")
		get_tree().quit()
		return
	
	if Global.player_id == "":
		print("❌ Player ID vazio - não é possível verificar")
		get_tree().quit()
		return
	
	print("🌐 Conectando ao Firebase para verificar dados...")
	print("Player ID: ", Global.player_id.substr(0, 8) + "...")
	
	# Conecta ao Firebase e busca os dados
	var firebase_ref = Firebase.Database.get_database_reference("players/" + Global.player_id, {})
	firebase_ref.connect("new_data_update", _on_firebase_data_received)
	firebase_ref.connect("no_data_update", _on_no_firebase_data)
	firebase_ref.get_data()
	
	# Timeout de 10 segundos
	await get_tree().create_timer(10.0).timeout
	print("⏰ Timeout - encerrando verificação")
	get_tree().quit()

func _on_firebase_data_received(data: Dictionary):
	print("📥 Dados recebidos do Firebase:")
	
	# Compara com dados locais
	var local_data = get_local_data()
	
	print("\n📊 COMPARAÇÃO DE DADOS:")
	print("=" * 50)
	
	var fields_to_check = ["name", "points", "gold", "crystal", "selected_avatar"]
	var all_match = true
	
	for field in fields_to_check:
		var firebase_value = data.get(field, "N/A")
		var local_value = local_data.get(field, "N/A")
		
		var match_status = "✅" if firebase_value == local_value else "❌"
		print("%s %s: Firebase=%s | Local=%s" % [match_status, field, firebase_value, local_value])
		
		if firebase_value != local_value:
			all_match = false
	
	print("=" * 50)
	
	# Verifica timestamps
	if data.has("last_updated"):
		var timestamp = data.last_updated
		var date_time = Time.get_datetime_dict_from_unix_time(timestamp)
		print("🕒 Última atualização: %02d/%02d/%d %02d:%02d:%02d" % [
			date_time.day, date_time.month, date_time.year,
			date_time.hour, date_time.minute, date_time.second
		])
	
	if data.has("synced_at"):
		var sync_timestamp = data.synced_at
		var sync_date_time = Time.get_datetime_dict_from_unix_time(sync_timestamp)
		print("🔄 Sincronizado em: %02d/%02d/%d %02d:%02d:%02d" % [
			sync_date_time.day, sync_date_time.month, sync_date_time.year,
			sync_date_time.hour, sync_date_time.minute, sync_date_time.second
		])
	
	print("\n🎯 RESULTADO FINAL:")
	if all_match:
		print("🎉 SUCESSO! Todos os dados foram sincronizados corretamente!")
		print("✅ Os dados em cache foram enviados com sucesso para o Firebase")
	else:
		print("⚠️ ATENÇÃO! Alguns dados não coincidem")
		print("❌ Pode haver problemas na sincronização")
	
	get_tree().quit()

func _on_no_firebase_data():
	print("❌ ERRO! Nenhum dado encontrado no Firebase!")
	print("💡 Isso pode indicar que:")
	print("   • Os dados não foram enviados")
	print("   • Há problemas de conectividade")
	print("   • O Player ID está incorreto")
	
	# Mostra dados locais para comparação
	var local_data = get_local_data()
	print("\n📁 Dados locais disponíveis:")
	for key in local_data:
		print("  %s: %s" % [key, local_data[key]])
	
	get_tree().quit()

func get_local_data() -> Dictionary:
	var data = {}
	
	# Dados do Global
	data["name"] = Global.player_name
	data["points"] = Global.points
	data["gold"] = Global.gold
	data["crystal"] = Global.crystal
	data["selected_avatar"] = Global.selected_avatar
	
	# Dados do arquivo local
	var config = ConfigFile.new()
	if config.load("user://player_config.cfg") == OK:
		data["local_name"] = config.get_value("player", "name", "")
		data["local_points"] = config.get_value("player", "points", 0)
		data["local_gold"] = config.get_value("player", "gold", 0)
		data["local_crystal"] = config.get_value("player", "crystal", 0)
	
	return data