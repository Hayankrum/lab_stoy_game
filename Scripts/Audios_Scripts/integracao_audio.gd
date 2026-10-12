# GUIA DE INTEGRAÇÃO — AudioManager no projeto
# =================================================
# Onde adicionar cada chamada de áudio nos scripts existentes.
#
# Pré-requisito: AudioManager.gd adicionado como AutoLoad em
# Projeto → Configurações → AutoLoad  (nome: AudioManager)

# ─────────────────────────────────────────────────────────────
# 1. EspacialController.gd
# ─────────────────────────────────────────────────────────────

# Em _ready(), após a cena carregar, inicia a música:
#   func _ready() -> void:
#       ...
#       AudioManager.start_music()        ← ADICIONAR

# Em _criar_bloco(), logo antes de _animar_entrada_bloco():
#   _animar_entrada_bloco(bloco)
#   AudioManager.sfx_reveal()            ← ADICIONAR

# Em _on_bloco_clicado(), quando o jogador abre um quarto:
#   func _on_bloco_clicado(...) -> void:
#       ...
#       AudioManager.sfx_open()           ← ADICIONAR
#       quarto.abrir(id_quarto, _dados, narrativa)

# ─────────────────────────────────────────────────────────────
# 2. QuartoController.gd
# ─────────────────────────────────────────────────────────────

# Em _avancar_dialogo(), quando o jogador avança uma fala:
#   func _avancar_dialogo() -> void:
#       ...
#       AudioManager.sfx_dialog()         ← ADICIONAR
#       _processar()

# Em _mostrar_escolhas(), dentro do btn.pressed.connect:
#   btn.pressed.connect(func():
#       AudioManager.sfx_click()          ← ADICIONAR
#       opcoes_container.visible = false
#       ...

# Em _quiz_responder(), dependendo do resultado:
#   if correta:
#       AudioManager.sfx_correct()        ← ADICIONAR
#   else:
#       AudioManager.sfx_wrong()          ← ADICIONAR

# ─────────────────────────────────────────────────────────────
# 3. Resumo da correspondência HTML → Godot
# ─────────────────────────────────────────────────────────────
#
#  HTML (nova_base.html)        Godot (AudioManager.gd)     Momento
#  ─────────────────────────────────────────────────────────────────
#  AudioEngine.sfxReveal()   → AudioManager.sfx_reveal()   Bloco aparece
#  AudioEngine.sfxClick()    → AudioManager.sfx_click()    Escolha/botão
#  AudioEngine.sfxDialog()   → AudioManager.sfx_dialog()   Avança fala
#  AudioEngine.sfxOpen()     → AudioManager.sfx_open()     Abre quarto
#  AudioEngine.sfxCorrect()  → AudioManager.sfx_correct()  Acerto no quiz
#  AudioEngine.sfxWrong()    → AudioManager.sfx_wrong()    Erro no quiz
#  AudioEngine.startMusic()  → AudioManager.start_music()  Inicia cena
#  AudioEngine.stopMusic()   → AudioManager.stop_music()   Pausa/menu

# ─────────────────────────────────────────────────────────────
# 4. Barramentos de áudio (opcional mas recomendado)
# ─────────────────────────────────────────────────────────────
# No editor Godot: Áudio → Barramentos de Áudio
# Crie dois barramentos:
#   - "Music"  (com efeito Reverb Room opcional)
#   - "SFX"
# Ambos conectados ao Master.
# O AudioManager usará esses barramentos automaticamente.
# Se não existirem, usará o Master como fallback.

# ─────────────────────────────────────────────────────────────
# 5. Controle de volume (para uma tela de configurações)
# ─────────────────────────────────────────────────────────────
#   AudioManager.music_volume = 0.4   # 0.0 a 1.0
#   AudioManager.sfx_volume   = 0.8
#   AudioManager.music_on     = false # muta música
#   AudioManager.sfx_on       = false # muta efeitos
