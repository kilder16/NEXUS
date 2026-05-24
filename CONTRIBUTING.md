# Contribuir a NEXUS

Documentación técnica para desarrolladores que quieran correr NEXUS desde código fuente, entender su arquitectura interna, o contribuir mejoras de cara a v1.1.

## Estado del proyecto

| Fase | Estado |
|------|--------|
| 1 — Prototipo | ✅ Completa |
| 2 — Menús y UI | ✅ Completa |
| 3 — Enemigos y armas | ✅ Completa |
| 4 — Niveles (5/5) | ✅ Completa |
| 5 — Multijugador | Planeada (sin fecha) |

Versión actual: **v1.0** (singleplayer completo, primer release público).

## Correr desde código

**Requisitos:**
- [Godot 4.6+](https://godotengine.org/download)
- Cualquier OS soportado por Godot (el juego se distribuye solo para Windows, pero el código corre en macOS y Linux desde el editor).

**Pasos:**

```bash
git clone https://github.com/kilder16/NEXUS.git
cd NEXUS
```

1. Abrir Godot → `Project → Import → seleccionar project.godot`.
2. **F5** para correr la escena principal (`scenes/ui/main_menu.tscn`).
3. **F6** para correr la escena actualmente abierta (útil para testear niveles aislados).
4. El primer lanzamiento genera audio procedural (~2–3 segundos); subsecuentes cargan de disco.

## Arquitectura

### Autoloads (singletons)

Configurados en `project.godot` bajo `[autoload]`:

- **`AudioManager`** (`scripts/systems/audio_manager.gd`) — manejo central de música y SFX, pitch variation en SFX repetidos, fade dinámico, generación procedural de WAV al primer launch (no se shipean assets de audio).
- **`ParticleManager`** (`scripts/systems/particle_manager.gd`) — pool de efectos GPU: muzzle flash, impact, blood, enemy death glitch, damage vignette.
- **`SettingsManager`** (`scripts/systems/settings_manager.gd`) — persistencia de settings gráficos en `user://settings.cfg` vía `ConfigFile`. Aplicación inmediata + propagación a `Viewport` para calidad.

### Jerarquía de enemigos

- **`enemy.gd`** (base) — `CharacterBody3D` con state machine `PATROL / CHASE / ATTACK / DEAD`, gravedad, lookup lazy de player, signal `died(enemy)`.
- **`enemy_fast.gd` / `enemy_tank.gd` / `enemy_ranged.gd`** — `extends "res://scripts/ai/enemy.gd"`. Sobreescriben `health`, `max_health`, `display_name`, `speed`, `attack_damage`, etc. tras `super._ready()`.
- **`enemy_ranged.gd`** sobreescribe además `do_chase()` y `do_attack()` para mantener distancia preferida y disparar `projectile.tscn` en lugar de melee.
- Todos se registran al grupo `"enemy"` en `_ready()` para que el `RayCast3D` del player pueda identificarlos (sistema de indicador de salud).

### Sistema de niveles

- Cada `scenes/levels/level_XX.tscn` tiene su `scripts/levels/level_XX.gd` (excepto cases sin lógica especial).
- **Patrón estándar**: trackear `start_time`, `enemies_killed`, `total_enemies`. Al pisar `Objective` (Area3D), llamar `win_screen.show_final_victory(elapsed, kills, total, title, narrative)`.
- **Boss-gate** solo en `level_05.gd`: `objective.monitoring = false` hasta matar boss; `BOSS_DEATH_DELAY = 1.5s` para pausa cinematográfica; override de `boss.health = 50` + sync de `max_health` + `display_name`.
- `objective.gd` tiene flag exportada `use_default_victory` — los level scripts la setean a `false` y manejan la victoria explícitamente.

### Sistema de armas

- Definidas en `player.gd::setup_weapons()` como instancias de la clase interna `Weapon` (nombre, daño, fire rate, range, spread, pellets).
- **Pistola**: 1 pellet, 0.2s cooldown, 50u range, sin spread.
- **Escopeta**: 6 pellets, 0.8s cooldown, 10u range, spread 0.12.
- **Rifle**: 2 pellets, 0.4s cooldown, 100u range.
- Disparo usa `PhysicsRayQueryParameters3D` por pellet (no usa el `RayCast3D` persistente del Camera3D, que está reservado para construcción + indicador de salud).

### UI

- **`HUD`** (`CanvasLayer`) con `process_mode = PROCESS_MODE_ALWAYS` — sigue procesando durante pause/winscreen para mantener el crosshair sincronizado con `Input.mouse_mode` y para fade del indicador de enemigos.
- **`EnemyHealthIndicator`** — driven por `player.gd::_update_enemy_indicator()` que consulta el `Camera3D/RayCast3D` ya existente (sin overhead extra), filtra por grupo `"enemy"` y distancia ≤40u.
- **`WinScreen`** reusable: `show_final_victory(seconds, kills, total, title := "", narrative := "")` — los dos últimos opcionales overridean el texto default (que es el de level_05: "NÚCLEO DESCONECTADO"). Cada level_XX.gd pasa sus propios strings.
- **`Pause menu`** + **`GameOver`** + **`Settings menu`** comparten patrón `process_mode = ALWAYS` para funcionar durante `get_tree().paused = true`.

### Audio

- 3-bus mixer: Master / Music (–8 dB) / SFX (–3 dB).
- Pitch variation en SFX repetidos (`play_sfx_pitched`).
- Loop seamless calculado para ambient music.
- Creación defensiva de buses en runtime para manejar timing de imports en primer launch.

### Visual FX

- `GPUParticles3D` con lifecycle auto-free (se destruyen al terminar la emisión).
- Shader custom `canvas_item` para damage vignette (`shaders/damage_vignette.gdshader`).
- Materiales emisivos para visibilidad en escenas oscuras (LED strips, screens, accent stripes).

## Roadmap

### v1.1 — planeada (sin fecha)

**Enemigos diferenciados con armas a distancia:**
- Centinela con arma corta (transición de melee a hibrido melee/ranged).
- Bastión con escudo destructible (capa de HP extra que el player debe romper antes del HP base).

**Armas nuevas:**
- Granadas (proyectil con timer + radio de explosión).
- Bazuca (proyectil de alto daño con splash).
- Cuchillo / hacha (melee).
- Sierra eléctrica (melee continuo).

### Fase 5 — Multijugador (planeada)

- Arquitectura multiplayer (decisión pendiente: ENet vs WebSocket).
- Campaña cooperativa (2-4 jugadores).
- Modo arena PvP.

## Convenciones de código

- GDScript con **tabs** (no spaces).
- Comentarios en español, identificadores en inglés (excepto strings de UI que son español).
- Una clase por archivo. `extends` siempre en primera línea.
- Para fixes complejos: comentario explica el "por qué" (root cause), no el "qué" (el código ya dice qué).

## Reportar bugs

Abrir issue en la pestaña [Issues del repo](https://github.com/kilder16/NEXUS/issues) con:
- Versión (v1.0, commit hash si aplica).
- OS + versión.
- Pasos para reproducir.
- Comportamiento esperado vs observado.
- Screenshot/clip si aplica.
