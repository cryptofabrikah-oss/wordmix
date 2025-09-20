extends Node

# Script de teste para verificar persistência de UID entre sessões

func _ready():
	print("🧪 TESTE DE PERSISTÊNCIA DE UID")
	print("=" * 50)
	
	test_persistencia_uid()

func test_persistencia_uid():
	# Simula múltiplas sessões para testar persistência
	print("\n📋 Testando persistência de UID entre sessões...")
	
	# Sessão 1 - Primeiro login
	print("\n🔹 SESSÃO 1 - Primeiro login")
	var uid_sessao1 = "test_uid_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)
	_simular_login(uid_sessao1)
	
	# Aguarda um pouco
	await get_tree().create_timer(1.0).timeout
	
	# Sessão 2 - Segundo login (deve manter o mesmo UID)
	print("\n🔹 SESSÃO 2 - Segundo login")
	var uid_sessao2 = "test_uid_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)
	_simular_login(uid_sessao2)
	
	# Sessão 3 - Terceiro login (deve manter o mesmo UID)
	print("\n🔹 SESSÃO 3 - Terceiro login")
	var uid_sessao3 = "test_uid_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)
	_simular_login(uid_sessao3)
	
	print("\n✅ Teste de persistência concluído!")

func _simular_login(novo_uid: String):
	print("   Novo UID recebido: ", novo_uid)
	
	# Simula carregar UID salvo (como o Global.gd faria)
	var uid_salvo = _carregar_uid_simulado()
	print("   UID salvo localmente: ", uid_salvo)
	
	# Lógica de persistência (como implementada no Global.gd)
	if uid_salvo != "" and uid_salvo != novo_uid:
		print("   ⚠️  UID diferente! Mantendo UID persistente: ", uid_salvo)
		_salvar_uid_simulado(uid_salvo)
		print("   ✅ Usando UID persistente")
	else:
		print("   ✅ UID consistente ou primeiro login")
		_salvar_uid_simulado(novo_uid)
		print("   ✅ Salvando novo UID")

func _salvar_uid_simulado(uid: String):
	# Simula salvamento em arquivo (como FileAccess.open_encrypted_with_pass)
	var config = ConfigFile.new()
	config.set_value("persistencia", "uid", uid)
	config.save("user://test_uid_save.cfg")
	print("   💾 UID salvo simulado: ", uid)

func _carregar_uid_simulado() -> String:
	# Simula carregamento de arquivo
	var config = ConfigFile.new()
	var err = config.load("user://test_uid_save.cfg")
	if err == OK:
		return config.get_value("persistencia", "uid", "")
	return ""

# Limpeza após teste
func _exit_tree():
	# Remove arquivo de teste
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove("test_uid_save.cfg")
		print("🧹 Arquivo de teste removido")