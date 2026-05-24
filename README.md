# NEXUS

> A tactical FPS with sandbox construction. Infiltrate. Adapt. Disconnect The Core.

`Built with Godot 4.6` · `GDScript` · `Status: Alpha v0.95` · `Singleplayer`

## Overview

NEXUS is a tactical first-person shooter built around a single core question: how do you survive when you can reshape the battlefield? Each level drops you into hostile territory with a fixed objective — reach the extraction zone — and a sandbox toolkit to get there. Combat is direct and decisive, but movement, cover, and verticality are entirely up to the player.

The campaign spans five hand-crafted levels with thematic progression, from open-field skirmishes in early encounters to claustrophobic warehouse engagements and a final boss arena set inside a high-tech server core. Enemies escalate in complexity: fast melee swarmers, ranged shooters that maintain distance, heavy tanks that absorb damage, and a scaled boss variant with override health.

The construction system is woven into combat rather than separated from it. Right-click drops a block (wall, ramp, or platform) at your raycast target. Cycle types mid-fight with Q/E. Players can build cover on the fly, create elevated firing positions, or barricade choke points — without ever leaving combat.

The final level, "The Core," is a tech-themed boss arena that contrasts visually with the industrial aesthetic of the rest of the campaign. The objective shifts from reaching extraction to neutralizing the AI core itself. Killing the boss triggers a cinematic 1.5-second pause before the extraction zone activates, followed by a victory screen showing run statistics.

## Features

### Combat System
- 3 weapons: pistol, shotgun (6-pellet spread), rifle
- 4 enemy types: fast melee, ranged shooters, heavy tanks, boss variant
- Idempotent damage handling (no double-kill bugs)
- Procedural audio with pitch variation

### Construction System
- Real-time block placement during combat
- Cycle through block types with Q/E
- Tactical use for cover or barricades

### Visual Feedback
- 5 particle effects: muzzle flash, wall impact, blood splatter, enemy death glitch, damage vignette
- Procedural audio system with 7+ sound effects + ambient music
- Cinematic boss death sequence (1.5s pause + audio fade)

### Level Design
- 5 hand-crafted levels with thematic progression:
  1. Open Field — Tutorial encounters
  2. Industrial Zone — Tight corridors
  3. Abandoned Military Base — Vertical combat
  4. Industrial Warehouse — Cover-based encounters
  5. The Core — Boss arena with tech-themed aesthetic

## Controls

| Action | Key |
|--------|-----|
| Move | WASD or Arrows |
| Look | Mouse |
| Jump | Space |
| Shoot / Destroy | Left Click |
| Place Block | Right Click |
| Cycle Block Type | Q / E |
| Switch Weapon | 1 / 2 / 3 |
| Restart Level | R |

## Technical Highlights

### Architecture
- Singleton pattern: AudioManager, ParticleManager
- Signal-based death notifications (`died` signal in base enemy class)
- Inheritance: `enemy_fast` / `enemy_tank` / `enemy_ranged` extend `enemy` base
- Opt-out victory pattern in `objective.gd` (`use_default_victory` flag)
- Defensive bus creation in runtime (handles import timing issues)

### Audio
- Procedural WAV generation on first launch (no audio assets shipped)
- 3-bus mixer: Master / Music (-8dB) / SFX (-3dB)
- Pitch variation on repeated SFX to avoid robotic feel
- Seamless loop calculation for ambient music

### Visual FX
- GPUParticles3D-based effects with auto-free lifecycle
- Custom `canvas_item` shader for damage vignette
- Emissive materials for visibility in dark scenes

## Project Status

- Phase 1 (Prototype): Complete
- Phase 2 (Menus & UI): Complete
- Phase 3 (Enemies & Weapons): Complete
- Phase 4 (Levels): Complete (5/5)
- Phase 5 (Multiplayer): Planned

Overall: ~94% complete (singleplayer)

## Roadmap

### Pending (Phase 5)
- Multiplayer architecture (ENet or WebSocket)
- Co-op campaign mode
- PvP arena mode

### Polish Backlog
- Enemy AI: melee attack range and aggression
- Boss death trigger animation
- More biomes for level variety
- Settings menu (volume, controls, graphics)

## Run Locally

```bash
git clone https://github.com/kilder16/NEXUS.git
cd NEXUS
```

1. Install [Godot 4.6+](https://godotengine.org/download)
2. Open the project: `Project → Import → select project.godot`
3. Press **F5** to run from the main scene, or **F6** to test the current scene
4. First launch generates procedural audio placeholders (~2–3 seconds); subsequent launches load from disk

## Credits

**Designed and developed by Leibnyz**

Developed with assistance from Claude (Anthropic) for code review, architecture decisions, and pair programming.
