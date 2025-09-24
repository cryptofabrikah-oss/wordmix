extends SceneTree

# Script para extrair palavras de 5 letras do arquivo icf.txt
# Execute com: godot --script extract_words.gd

func _ready():
	print("Iniciando extração de palavras...")
	extract_words()
	quit()

func is_valid_word(word: String) -> bool:
	# Verifica se tem exatamente 5 caracteres
	if word.length() != 5:
		return false
	
	# Verifica se contém apenas letras (incluindo acentos portugueses)
	var regex = RegEx.new()
	regex.compile("^[a-záàâãéèêíìîóòôõúùûçñA-ZÁÀÂÃÉÈÊÍÌÎÓÒÔÕÚÙÛÇÑ]+$")
	if not regex.search(word):
		return false
	
	# Lista de fragmentos comuns que devem ser evitados
	var invalid_fragments = [
		"mente", "ações", "antes", "entes", "intes", "ontes", "untes",
		"áveis", "íveis", "árias", "érias", "írias", "órias", "úrias",
		"ismos", "istas", "izars", "ções", "dades"
	]
	
	var word_lower = word.to_lower()
	for fragment in invalid_fragments:
		if word_lower == fragment:
			return false
	
	# Lista de palavras muito comuns que são válidas (whitelist)
	var common_valid_words = [
		"muito", "sobre", "mesmo", "todos", "ainda", "entre", "fazer",
		"paulo", "minha", "tempo", "assim", "agora", "mundo", "forma",
		"parte", "estão", "foram", "todas", "então", "maior", "disse",
		"feira", "nossa", "outro", "nosso", "tenho", "menos", "vezes",
		"antes", "sendo", "podem", "estou", "pouco", "desde", "saúde",
		"nunca", "coisa", "tinha", "livro", "estar", "hotel", "neste",
		"pelos", "outra", "final", "conta", "saber", "grupo", "lugar"
	]
	
	if word_lower in common_valid_words:
		return true
	
	# Verifica padrões suspeitos que podem indicar fragmentos
	var suspicious_patterns = [
		"^[aeiouáàâãéèêíìîóòôõúùû]{2,}",  # Muitas vogais seguidas no início
		"[aeiouáàâãéèêíìîóòôõúùû]{3,}",   # Três ou mais vogais seguidas
		"^[bcdfghjklmnpqrstvwxyzçñ]{3,}",  # Muitas consoantes seguidas no início
		"[bcdfghjklmnpqrstvwxyzçñ]{4,}"    # Quatro ou mais consoantes seguidas
	]
	
	for pattern in suspicious_patterns:
		var pattern_regex = RegEx.new()
		pattern_regex.compile(pattern)
		if pattern_regex.search(word_lower):
			return false
	
	return true

func extract_words():
	var file = FileAccess.open("icf.txt", FileAccess.READ)
	if not file:
		print("Erro: Não foi possível abrir o arquivo icf.txt")
		return
	
	var words_by_level = {}
	var all_words = []
	var valid_count = 0
	var total_count = 0
	
	# Inicializa os níveis
	for i in range(1, 12):
		words_by_level[i] = []
	
	print("Processando arquivo icf.txt...")
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		
		var parts = line.split(",")
		if parts.size() != 2:
			continue
		
		var word = parts[0].strip_edges()
		var frequency = parts[1].to_float()
		
		total_count += 1
		
		# Só processa palavras de 5 letras
		if word.length() == 5 and is_valid_word(word):
			valid_count += 1
			
			# Determina o nível baseado na frequência
			var level = get_frequency_level(frequency)
			words_by_level[level].append(word)
			all_words.append(word)
			
			if valid_count % 100 == 0:
				print("Palavras válidas encontradas: ", valid_count)
	
	file.close()
	
	print("Processamento concluído!")
	print("Total de linhas processadas: ", total_count)
	print("Palavras válidas de 5 letras encontradas: ", valid_count)
	
	# Salva words.json (formato simples)
	save_words_json(all_words)
	
	# Salva words_frequency_levels.json (formato detalhado)
	save_frequency_levels_json(words_by_level)
	
	# Salva words_complete_data.json (dados completos)
	save_complete_data_json(words_by_level, valid_count)

func get_frequency_level(frequency: float) -> int:
	# Mapeia frequência para níveis (1-11)
	if frequency <= 6.0:
		return 1  # Muito frequentes
	elif frequency <= 7.0:
		return 2  # Frequentes
	elif frequency <= 8.0:
		return 3  # Comuns
	elif frequency <= 9.0:
		return 4  # Moderadamente comuns
	elif frequency <= 10.0:
		return 5  # Médias
	elif frequency <= 11.0:
		return 6  # Menos frequentes
	elif frequency <= 12.0:
		return 7  # Raras
	elif frequency <= 13.0:
		return 8  # Muito raras
	elif frequency <= 14.0:
		return 9  # Extremamente raras
	elif frequency <= 15.0:
		return 10  # Quase inexistentes
	else:
		return 11  # Inexistentes

func save_words_json(words: Array):
	var file = FileAccess.open("words.json", FileAccess.WRITE)
	if not file:
		print("Erro: Não foi possível criar words.json")
		return
	
	var json_string = JSON.stringify(words)
	file.store_string(json_string)
	file.close()
	print("Arquivo words.json salvo com ", words.size(), " palavras")

func save_frequency_levels_json(words_by_level: Dictionary):
	var levels_data = {}
	
	var level_names = [
		"", # índice 0 não usado
		"Nível 1 - Muito frequentes",
		"Nível 2 - Frequentes", 
		"Nível 3 - Comuns",
		"Nível 4 - Moderadamente comuns",
		"Nível 5 - Médias",
		"Nível 6 - Menos frequentes",
		"Nível 7 - Raras",
		"Nível 8 - Muito raras",
		"Nível 9 - Extremamente raras",
		"Nível 10 - Quase inexistentes",
		"Nível 11 - Inexistentes"
	]
	
	var frequency_ranges = [
		"", # índice 0 não usado
		"≤ 6.0",
		"6.0 - 7.0",
		"7.0 - 8.0", 
		"8.0 - 9.0",
		"9.0 - 10.0",
		"10.0 - 11.0",
		"11.0 - 12.0",
		"12.0 - 13.0",
		"13.0 - 14.0",
		"14.0 - 15.0",
		"> 15.0"
	]
	
	for level in range(1, 12):
		if words_by_level.has(level) and words_by_level[level].size() > 0:
			levels_data[str(level)] = {
				"name": level_names[level],
				"frequency_range": frequency_ranges[level],
				"word_count": words_by_level[level].size(),
				"words": words_by_level[level]
			}
	
	var file = FileAccess.open("words_frequency_levels.json", FileAccess.WRITE)
	if not file:
		print("Erro: Não foi possível criar words_frequency_levels.json")
		return
	
	var json_string = JSON.stringify(levels_data)
	file.store_string(json_string)
	file.close()
	print("Arquivo words_frequency_levels.json salvo")

func save_complete_data_json(words_by_level: Dictionary, total_words: int):
	var complete_data = {
		"metadata": {
			"total_words": total_words,
			"extraction_date": Time.get_datetime_string_from_system(),
			"levels_count": 11,
			"source_file": "icf.txt"
		},
		"levels": {}
	}
	
	for level in range(1, 12):
		if words_by_level.has(level):
			complete_data.levels[str(level)] = {
				"word_count": words_by_level[level].size(),
				"words": words_by_level[level]
			}
	
	var file = FileAccess.open("words_complete_data.json", FileAccess.WRITE)
	if not file:
		print("Erro: Não foi possível criar words_complete_data.json")
		return
	
	var json_string = JSON.stringify(complete_data)
	file.store_string(json_string)
	file.close()
	print("Arquivo words_complete_data.json salvo")