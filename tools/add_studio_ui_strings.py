"""Port-specific hub labels, kept in the shared localization bank."""
import json
from pathlib import Path
path = Path(__file__).resolve().parents[1]/'assets/localization/ui.json'
data = json.loads(path.read_text(encoding='utf8'))
strings = {
 'Plató': ['Plató','Studio','Estúdio','Studio'],
 'Laboratorio': ['Laboratorio','Laboratory','Laboratório','Laboratorio'],
 'Esc: guardar · Enter: plató': ['Esc: guardar · Enter: plató','Esc: save · Enter: studio','Esc: salvar · Enter: estúdio','Esc: salva · Enter: studio'],
 'Progreso sin guardar · Esc: guardar': ['Progreso sin guardar · Esc: guardar','Unsaved progress · Esc: save','Progresso não salvo · Esc: salvar','Progressi non salvati · Esc: salva'],
 'Cargar partida en el plató': ['Cargar partida en el plató','Load game in studio','Carregar jogo no estúdio','Carica partita nello studio'],
 'Guardar partida': ['Guardar partida','Save game','Salvar jogo','Salva partita'],
 'Partida guardada': ['Partida guardada','Game saved','Jogo salvo','Partita salvata'],
 'Guardado automático': ['Guardado automático','Autosave','Salvamento automático','Salvataggio automatico'],
 'Guardado automático al completar un nivel': ['Guardado automático al completar un nivel','Autosaved upon completing a level','Salvo automaticamente ao concluir um nível','Salvataggio automatico al completamento del livello'],
 'Partida guardada automáticamente': ['Partida guardada automáticamente','Game autosaved','Jogo salvo automaticamente','Partita salvata automaticamente'],
 'No se pudo guardar automáticamente (%d)': ['No se pudo guardar automáticamente (%d)','Autosave failed (%d)','Falha ao salvar automaticamente (%d)','Salvataggio automatico fallito (%d)'],
 'Enter: plató': ['Enter: plató','Enter: studio','Enter: estúdio','Enter: studio']}
for key, translations in strings.items():
    for locale, value in zip(['es','en','pt_BR','it'], translations):
        data.setdefault(locale,{})[key] = value
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
