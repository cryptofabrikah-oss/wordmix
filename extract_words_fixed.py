#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import re
from collections import defaultdict

def is_valid_word(word):
    """
    Valida se uma palavra é adequada para o jogo:
    - Deve ter exatamente 5 letras
    - Deve conter apenas letras (incluindo acentos)
    - Não deve ser um fragmento comum
    """
    # Verifica se tem exatamente 5 caracteres
    if len(word) != 5:
        return False
    
    # Verifica se contém apenas letras (incluindo acentos portugueses)
    if not re.match(r'^[a-záàâãéèêíìîóòôõúùûçñ]+$', word, re.IGNORECASE):
        return False
    
    # Lista de fragmentos comuns que devem ser evitados (apenas palavras de 5 letras)
    invalid_fragments = {
        'mente', 'ações', 'antes', 'entes', 'intes', 'ontes', 'untes',
        'áveis', 'íveis', 'árias', 'érias', 'írias', 'órias', 'úrias',
        'ismos', 'istas', 'izars', 'entes', 'antes', 'ções', 'dades'
    }
    
    # Verifica se a palavra não é um fragmento comum
    if word.lower() in invalid_fragments:
        return False
    
    # Lista de palavras muito comuns que são válidas (whitelist)
    common_valid_words = {
        'muito', 'sobre', 'mesmo', 'todos', 'ainda', 'entre', 'fazer',
        'paulo', 'minha', 'tempo', 'assim', 'agora', 'mundo', 'forma',
        'parte', 'estão', 'foram', 'todas', 'então', 'maior', 'disse',
        'feira', 'nossa', 'outro', 'nosso', 'tenho', 'menos', 'vezes',
        'antes', 'sendo', 'podem', 'estou', 'pouco', 'desde', 'saúde',
        'nunca', 'coisa', 'tinha', 'livro', 'estar', 'hotel', 'neste',
        'pelos', 'outra', 'final', 'conta', 'saber', 'grupo', 'lugar'
    }
    
    # Se está na whitelist, é válida
    if word.lower() in common_valid_words:
        return True
    
    # Verifica padrões suspeitos que podem indicar fragmentos
    suspicious_patterns = [
        r'^[aeiou]{2,}',  # Muitas vogais seguidas no início
        r'[aeiou]{3,}',   # Três ou mais vogais seguidas
        r'^[bcdfghjklmnpqrstvwxyz]{3,}',  # Muitas consoantes seguidas no início
        r'[bcdfghjklmnpqrstvwxyz]{4,}',   # Quatro ou mais consoantes seguidas
    ]
    
    for pattern in suspicious_patterns:
        if re.search(pattern, word.lower()):
            return False
    
    return True

def process_icf_file():
    print("🔍 Processando icf.txt com validação aprimorada...")
    
    try:
        with open('icf.txt', 'r', encoding='utf-8') as file:
            content = file.read()
    except FileNotFoundError:
        print("❌ Arquivo icf.txt não encontrado!")
        return
    
    # Parse do conteúdo
    words_with_freq = {}
    total_processed = 0
    valid_words = 0
    
    # Divide por vírgulas e processa cada item
    items = content.split(',')
    
    for item in items:
        item = item.strip().strip('"').strip("'")
        total_processed += 1
        
        if total_processed % 50000 == 0:
            print(f"📊 Processados: {total_processed}, Válidos: {valid_words}")
        
        # Tenta extrair palavra e frequência
        # Formato esperado: "palavra" seguida de número
        parts = item.split()
        if len(parts) >= 2:
            word_part = parts[0]
            try:
                freq_part = float(parts[-1])
                
                # Valida a palavra
                if is_valid_word(word_part):
                    # Mantém acentos originais
                    clean_word = word_part.lower().strip()
                    if clean_word not in words_with_freq or words_with_freq[clean_word] < freq_part:
                        words_with_freq[clean_word] = freq_part
                        valid_words += 1
            except ValueError:
                continue
    
    print(f"✅ Processamento concluído!")
    print(f"📊 Total processado: {total_processed}")
    print(f"📊 Palavras válidas encontradas: {len(words_with_freq)}")
    
    if not words_with_freq:
        print("❌ Nenhuma palavra válida encontrada!")
        return
    
    # Organiza por frequência (maior frequência = menor número de nível)
    sorted_words = sorted(words_with_freq.items(), key=lambda x: x[1], reverse=True)
    
    # Cria níveis de frequência
    frequency_levels = {}
    words_per_level = len(sorted_words) // 11  # 11 níveis
    
    for level in range(1, 12):  # Níveis 1-11
        start_idx = (level - 1) * words_per_level
        end_idx = start_idx + words_per_level if level < 11 else len(sorted_words)
        
        level_words = [word for word, freq in sorted_words[start_idx:end_idx]]
        level_freqs = [freq for word, freq in sorted_words[start_idx:end_idx]]
        
        frequency_levels[str(level)] = {
            "level": level,
            "description": f"Nível {level} - {'Muito frequentes' if level <= 3 else 'Frequentes' if level <= 6 else 'Menos frequentes'}",
            "word_count": len(level_words),
            "frequency_range": {
                "min": min(level_freqs) if level_freqs else 0,
                "max": max(level_freqs) if level_freqs else 0
            },
            "words": level_words
        }
        
        print(f"📊 Nível {level}: {len(level_words)} palavras (freq: {min(level_freqs):.2f} - {max(level_freqs):.2f})")
    
    # Salva arquivos
    print("💾 Salvando arquivos...")
    
    # 1. words.json (lista simples para compatibilidade)
    all_words = [word for word, freq in sorted_words]
    with open('words.json', 'w', encoding='utf-8') as f:
        json.dump(all_words, f, ensure_ascii=False, indent=2)
    
    # 2. words_frequency_levels.json (sistema de níveis)
    with open('words_frequency_levels.json', 'w', encoding='utf-8') as f:
        json.dump(frequency_levels, f, ensure_ascii=False, indent=2)
    
    # 3. words_complete_data.json (dados completos)
    complete_data = {
        "metadata": {
            "total_words": len(words_with_freq),
            "levels": 11,
            "extraction_date": "2024-01-24",
            "validation": "enhanced"
        },
        "frequency_levels": frequency_levels,
        "word_frequency_map": words_with_freq
    }
    
    with open('words_complete_data.json', 'w', encoding='utf-8') as f:
        json.dump(complete_data, f, ensure_ascii=False, indent=2)
    
    print("✅ Arquivos salvos com sucesso!")
    print(f"📁 words.json: {len(all_words)} palavras")
    print(f"📁 words_frequency_levels.json: 11 níveis de frequência")
    print(f"📁 words_complete_data.json: dados completos")
    
    # Mostra exemplos de cada nível
    print("\n🎯 Exemplos por nível:")
    for level in range(1, min(6, len(frequency_levels) + 1)):
        level_words = frequency_levels[str(level)]["words"]
        examples = level_words[:10] if len(level_words) >= 10 else level_words
        print(f"   Nível {level}: {', '.join(examples)}")

if __name__ == "__main__":
    process_icf_file()