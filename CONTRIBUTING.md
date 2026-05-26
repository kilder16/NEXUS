# Contribuir a NEXUS

Documentación técnica para desarrolladores que quieran correr NEXUS desde código fuente, entender su arquitectura interna, o contribuir mejoras de cara a v1.2.

## Estado del proyecto

| Fase | Estado |
|------|--------|
| 1 — Prototipo | ✅ Completa |
| 2 — Menús y UI | ✅ Completa |
| 3 — Enemigos y armas | ✅ Completa |
| 4 — Niveles (5/5) | ✅ Completa |
| v1.1 — Expansión combate + polish | ✅ Completa |
| 5 — Multijugador | Planeada (sin fecha) |

Versión actual: **v1.1** (expansión de combate: loadout 8 armas, enemigos diferenciados, gunplay polish).

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

- **`enemy.gd`** (base = **Centinela**, ranged corto en v1.1) — `CharacterBody3D` con state machine `PATROL / CHASE / ATTACK / DEAD`, gravedad, lookup lazy de player, signal `died(enemy)`. Soporta **escudo opcional** (`shield`/`max_shield`, default 0) que absorbe daño antes que el HP; overflow del último golpe pasa al HP. Hooks virtuales `_on_shield_hit()` y `_on_shield_broken()` para que subclases con escudo disparen VFX. Dispara `projectile_short.tscn` cuando `attack_timer` expira (handler `_perform_attack()` virtual, default = ranged).
- **`enemy_fast.gd` / `enemy_tank.gd` / `enemy_ranged.gd`** — `extends "res://scripts/ai/enemy.gd"`. Sobreescriben `health`, `max_health`, `display_name`, `speed`, `attack_damage`, etc. tras `super._ready()`. `enemy_fast` (Asaltante) y `enemy_tank` (Bastión) overridean `_perform_attack()` con melee para preservar su patrón original tras el cambio del Centinela a ranged. `enemy_tank` agrega `shield = 4` y override de `_on_shield_broken()` con VFX `shield_break.tscn` + control del aura cyan (`ShieldVisual` en la escena).
- **`enemy_ranged.gd`** (Tirador) sobreescribe `do_chase()` y `do_attack()` completos para mantener distancia preferida y disparar `projectile.tscn`. El retroceso valida piso atrás con un raycast probe (no se tira al vacío en bordes).
- Todos se registran al grupo `"enemy"` en `_ready()`. Cada escena de enemigo incluye un **`HeadHitbox`** (Area3D, SphereShape3D radius 0.35 a Y=0.7) en grupo `"head_hitbox"` que `player._fire_hitscan` detecta con un raycast adicional para aplicar daño x2 + SFX `headshot_ding`.

### Sistema de niveles

- Cada `scenes/levels/level_XX.tscn` tiene su `scripts/levels/level_XX.gd` (excepto cases sin lógica especial).
- **Patrón estándar**: trackear `start_time`, `enemies_killed`, `total_enemies`. Al pisar `Objective` (Area3D), llamar `win_screen.show_final_victory(elapsed, kills, total, title, narrative)`.
- **Boss-gate** solo en `level_05.gd`: `objective.monitoring = false` hasta matar boss; `BOSS_DEATH_DELAY = 1.5s` para pausa cinematográfica; override de `boss.health = 50`, `boss.shield = 15` (v1.1, boss más blindado que un Bastión normal) + sync de `max_health`/`max_shield` + `display_name`.
- `objective.gd` tiene flag exportada `use_default_victory` — los level scripts la setean a `false` y manejan la victoria explícitamente.
- **Override per-level por iteración** (patrón v1.1, usado para balance): el level script preloadea el script del enemy a tunear (`const ENEMY_BASE_SCRIPT: Script = preload(...)`) e itera children en `_ready` con `child.get_script() == ENEMY_BASE_SCRIPT` para tocar stats específicos sin afectar otros niveles. Ejemplos: `level_01.gd` baja el cooldown del Centinela a 2.5s; `level_05.gd` sube el `detect_range` del Tirador a 22u (su spawn queda a ~17u, por encima del default 15u).

### Sistema de armas

- Definidas en `player.gd::setup_weapons()` como instancias de `Weapon` (`scripts/weapons/weapon.gd`, RefCounted). 8 slots en v1.1.
- Campos: `weapon_name`, `damage`, `fire_rate`, `max_range`, `spread`, `pellets`, `max_ammo` / `ammo` (`<0` = infinita), `type`, `sfx_name`, `vfx_color`, `recoil_amount` (rad), `recoil_recovery_time` (s).
- **`type`** discrimina el handler en `player.gd::shoot()`:
  - `"hitscan"` → `_fire_hitscan(w)` (raycast por pellet + recoil + headshot detection).
  - `"grenade"` → `_throw_grenade(w)` (instancia RigidBody3D con arco físico, fuse 2s).
  - `"rocket"` → `_fire_rocket(w)` (instancia Area3D con velocidad lineal, impacta en cualquier body).
  - `"melee_swing"` → `do_melee_swing(damage, range, sfx_name, vfx_color)` (raycast corto + spawn slash VFX + camera shake pulse).
  - `"melee_held"` → `pass` en `shoot()`; toda la lógica vive en `_physics_process::_update_saw_input` (input held, tick de daño cada 0.1s, GPUParticles3D persistente para chispas, audio loop vía `AudioManager.play_sfx_loop`).

| # | Arma | Tipo | Daño | Rate / Cooldown | Ammo | Range / Radio |
|---|------|------|------|-----------------|------|---------------|
| 1 | Pistola | hitscan | 1 | 0.2s | ∞ | 50u |
| 2 | Escopeta | hitscan | 3 (×6 pellets, spread 0.12) | 0.8s | ∞ | 10u |
| 3 | Rifle | hitscan | 2 (×2 pellets) | 0.4s | ∞ | 100u |
| 4 | Granada | grenade | 10 (dropoff lineal) | 2.0s | 3/nivel | radio 5u |
| 5 | Bazuca | rocket | 15 (dropoff lineal) | 1.5s | 2/nivel | radio 4u |
| 6 | Cuchillo | melee_swing | 5 | 0.3s | ∞ | 2u |
| 7 | Hacha | melee_swing | 12 | 0.8s | ∞ | 2.5u |
| 8 | Sierra | melee_held | 2 cada 0.1s = 20 DPS | continuo | ∞ | 2u |

- **Recoil** (solo hitscan): mantiene `_recoil_offset` acumulado; en `_fire_hitscan` suma `w.recoil_amount` al offset y baja `camera.rotation.x` (pitch up); en `_physics_process` decae con velocidad `3.0 / w.recoil_recovery_time` y aplica el delta a `camera.rotation.x` (lo sube). No pisa el input del mouse: solo aplica el delta del decay.
- **Headshots** (solo hitscan): `_fire_hitscan` hace 2 raycasts independientes — `body_query` con `collide_with_bodies=true / areas=false`, `head_query` con `bodies=false / areas=true`. Es headshot cuando el `head_result.collider` (Area3D del grupo `"head_hitbox"`) pertenece al mismo enemy del `body_result` (`head_owner == body_owner`); o cuando sólo el head ray pega y el body no. Daño × 2 + `headshot_ding`.
- **Munición limitada**: `consume_ammo()` se llama en `shoot()` tras el match; si `has_ammo()` retorna false, SFX `empty_click` + return. Reset implícito en cada `_ready` del player (cada nivel arranca con ammo full).
- **Granadas/cohetes** dañan SOLO enemigos (iteran `get_tree().get_nodes_in_group("enemy")` y aplican dropoff lineal). No friendly fire.

### UI

- **`HUD`** (`CanvasLayer`) con `process_mode = PROCESS_MODE_ALWAYS` — sigue procesando durante pause/winscreen para mantener el crosshair sincronizado con `Input.mouse_mode` y para fade del indicador de enemigos.
- **`WeaponBox`** (v1.1) — VBox con `WeaponNameLabel` + `WeaponSlotsHBox` (8 `PanelContainer`) + `AmmoLabel`. `hud.update_weapon(name, current_index, total_weapons)` aplica 3 StyleBoxFlat creados en `_ready` (active cyan / available oscuro / empty gris) según el slot. `update_ammo(current, max)` oculta el label si `max < 0` (munición infinita).
- **`EnemyHealthIndicator`** — driven por `player.gd::_update_enemy_indicator()` que consulta el `Camera3D/RayCast3D` ya existente (sin overhead extra), filtra por grupo `"enemy"` y distancia ≤40u. En v1.1 muestra 2 barras (cyan escudo + verde/amarillo/rojo HP) cuando `enemy.max_shield > 0 and shield > 0`.
- **`DamageEdgeLeft/Right/Top/Bottom`** (v1.1) — 4 ColorRect rojos en los bordes del HUD; `show_damage_indicator(dir)` tween de alpha 0.6→0 en 1s. `player.take_damage(amount, attacker_position)` discretiza al eje dominante (`transform.basis.x.dot` y `.z.dot` sobre `to_attacker`) y llama al edge correspondiente. Callers actualizados: `projectile.gd`, `projectile_short.gd` (pasan `shooter.global_position`), `enemy_tank/fast.gd::_perform_attack` (pasan `self.global_position`).
- **`Settings menu`** ahora es **dual** (v1.1): standalone (desde main menu, scene swap) u **overlay** (desde pause). `pause_menu.gd::_on_settings_button_pressed` instancia `settings_menu.tscn`, llama `open_as_overlay()` (setea `overlay_mode = true` + `process_mode = ALWAYS`) y agrega como hijo del PauseMenu — sin tocar `tree.paused`. Al cerrar, signal `closed` → `queue_free` + re-show de los botones del pause.
- **`WinScreen`** reusable: `show_final_victory(seconds, kills, total, title := "", narrative := "")` — los dos últimos opcionales overridean el texto default (que es el de level_05: "NÚCLEO DESCONECTADO"). Cada level_XX.gd pasa sus propios strings.
- **`Pause menu`** + **`GameOver`** + **`Settings menu`** comparten patrón `process_mode = ALWAYS` para funcionar durante `get_tree().paused = true`.
- **Hitmarker visual** diferido a v1.2: el HUD `CanvasLayer` actual no renderiza `_draw()` custom ni Controls con `rotation` aplicada (root cause no diagnosticado). El SFX `hitmarker_tick` cubre el feedback auditivo en v1.1.

### Audio

- 3-bus mixer: Master / Music (–8 dB) / SFX (–3 dB).
- Pitch variation en SFX repetidos (`play_sfx_pitched`).
- Loop seamless calculado para ambient music (frecuencias eligen ciclos enteros sobre la duración del sample para que `sample[0] == sample[n]` y el wrap no produzca pop).
- **Loops de SFX controlables** (v1.1): `play_sfx_loop(name) → AudioStreamPlayer` crea un player dedicado fuera del pool one-shot, con el stream configurado a `LOOP_FORWARD`; `stop_sfx_loop(player)` lo apaga y `queue_free`. Usado por la sierra eléctrica (motor en loop mientras LMB held). Reusable para futuras armas con loop (lanzallamas, jetpack).
- Creación defensiva de buses en runtime para manejar timing de imports en primer launch.
- SFX procedurales agregados en v1.1: `empty_click` (vacío al disparar sin munición), `explosion` (granada/cohete), `stab` (cuchillo), `chop` (hacha), `saw_motor` (sierra, loop), `hitmarker_tick` (impacto enemy), `double_jump` (segundo salto), `headshot_ding` (headshot premium).

### Visual FX

- `GPUParticles3D` con lifecycle auto-free (se destruyen al terminar la emisión).
- Shader custom `canvas_item` para damage vignette (`shaders/damage_vignette.gdshader`).
- Materiales emisivos para visibilidad en escenas oscuras (LED strips, screens, accent stripes).

## Roadmap

### v1.1 — completada ✅

**Enemigos diferenciados:**
- ✅ Centinela con arma corta (ranged 6u, proyectil amarillo).
- ✅ Bastión con escudo destructible (4 HP de escudo sobre HP base; boss del Sector 05 escalado a escudo 15 + HP 50).

**Armas nuevas (slots 4-8):**
- ✅ Granada (slot 4): RigidBody3D con fuse 2s, radio 5u, daño 10 con dropoff.
- ✅ Bazuca (slot 5): Area3D con velocidad lineal, radio 4u, daño 15 con dropoff.
- ✅ Cuchillo (slot 6): melee_swing, daño 5, rango 2u, cooldown 0.3s.
- ✅ Hacha (slot 7): melee_swing, daño 12, rango 2.5u, cooldown 0.8s.
- ✅ Sierra eléctrica (slot 8): melee_held (DPS continuo, 20/s), rango 2u.

**Gunplay polish:**
- ✅ Doble salto con SFX/VFX.
- ✅ Recoil per-arma (pistola/rifle/escopeta).
- ✅ Damage indicator direccional (4 bordes).
- ✅ Headshots con daño x2 + SFX "ding".
- ✅ SFX hitmarker tick (el visual quedó diferido a v1.2).

**Otros:**
- ✅ Settings overlay (no reinicia el nivel).
- ✅ UI armas extendida a 8 slots.
- ✅ Munición limitada en granada y bazuca.

### v1.2 — planeada (sin fecha)

- **Hitmarker visual** — chevrons amarillos alrededor del crosshair al impactar. Diferido por bug del HUD `CanvasLayer` (no renderiza `_draw()` ni Controls con rotation; root cause pendiente de diagnóstico, probable rediseño del HUD).
- **Indicador de alcance del crosshair** — color verde/amarillo/rojo según distancia al objetivo apuntado y `max_range` del arma activa.
- **Modelo 3D del boss** — reemplazar la cápsula default del Sector 05 por un mesh decente con animaciones básicas (descartado para v1.1 porque el modelo Sketchfab inicial era de impresión 3D, 900k tris, sin animaciones).
- **Versión Android** (port + controles touch).

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
- Versión (v1.1, commit hash si aplica).
- OS + versión.
- Pasos para reproducir.
- Comportamiento esperado vs observado.
- Screenshot/clip si aplica.
