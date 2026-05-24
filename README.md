# NEXUS

> Infiltrate. Adapt. Disconnect The Core.

![Version](https://img.shields.io/badge/version-1.0-blue)
![Engine](https://img.shields.io/badge/Godot-4.6-478CBF?logo=godot-engine&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6?logo=windows&logoColor=white)
![License](https://img.shields.io/badge/license-Proprietary-red)

## Sobre el juego

NEXUS es un FPS táctico en primera persona con un sistema de construcción integrado al combate. Cada nivel te suelta en territorio hostil con un objetivo fijo —alcanzar la zona de extracción— y una caja de herramientas para reformar el campo de batalla en tiempo real. El tono es infiltración sci-fi oscura: Nexus es una IA hostil que controla cinco sectores, y vos sos el operador enviado a desconectar su Núcleo, sector por sector.

## Características

### 5 niveles diseñados a mano
1. **Sector 01 — Infiltración** · Pasillo de tutorial implícito en estética sci-fi azul.
2. **Sector 02 — Industrial** · Complejo segmentado con corridors, midroom y plataforma final.
3. **Sector 03 — Complejo Militar** · Hangar abierto con vehículo abandonado, escalera a sala de control superior.
4. **Sector 04 — Almacén** · Depósito con shelves, contenedores y un jefe local en oficina trasera.
5. **Sector 05 — El Núcleo** · Arena octogonal tech-themed con gate progresivo: la zona de extracción solo se activa al matar al boss.

### Enemigos (4 tipos + boss)
- **Centinela** — patrullero base, 3 HP, daño 1.
- **Asaltante** — rápido y frágil, 2 HP, daño 2.
- **Bastión** — tank lento, 8 HP, daño 1.
- **Tirador** — francotirador que mantiene distancia, 4 HP.
- **JEFE: NÚCLEO** — boss del Sector 05, variante escalada de Bastión, 50 HP.

### Sistemas
- **Construcción en tiempo real** — muros, rampas o plataformas con clic derecho. Cambiá tipo con Q/E sin pausar combate.
- **3 armas** — pistola (precisa), escopeta (6 pellets con spread), rifle (alto daño).
- **Configuración gráfica persistente** — fullscreen, VSync y calidad (Baja/Media/Alta) guardadas en `user://settings.cfg`.
- **Indicador de salud de enemigos** estilo Halo — barra horizontal sobre el crosshair al apuntar a un enemigo a ≤40u, con nombre, HP numérico y color por umbral.
- **Pause menu + WinScreen con stats** — tiempo y enemigos eliminados al cerrar cada sector.
- **Audio procedural** — SFX y música generados al primer launch, con pitch variation y fade dinámico.

## Controles

| Acción | Tecla |
|--------|-------|
| Mover | WASD o flechas |
| Mirar | Mouse |
| Saltar | Espacio |
| Disparar / destruir | Clic izquierdo |
| Construir bloque | Clic derecho |
| Cambiar tipo de bloque | Q / E |
| Cambiar arma | 1 / 2 / 3 |
| Reiniciar nivel | R |
| Pausa / menú | ESC |

## Cómo jugar

Esta es la versión **v1.0**, primer release público.

1. Descargá el `.exe` de la última versión desde **[Releases en GitHub](https://github.com/kilder16/NEXUS/releases)**.
2. Extraé el zip y ejecutá `nexus.exe`.
3. Plataforma soportada: **Windows 10 / 11 (64-bit)**.

El primer lanzamiento genera archivos de audio procedurales (~2–3 segundos); los lanzamientos siguientes cargan de disco.

## Tecnologías

- [**Godot 4.6**](https://godotengine.org/) — motor 3D, renderer Forward+, backend D3D12 en Windows.
- **GDScript** — toda la lógica de gameplay.
- **Jolt Physics** — motor de física 3D.

## Roadmap v1.1

Planeado, sin fecha confirmada:

- **Enemigos diferenciados con armas a distancia**
  - Centinela con arma corta.
  - Bastión con escudo destructible.
- **Armas nuevas**: granadas, bazuca, cuchillo, hacha, sierra eléctrica.
- **Multijugador cooperativo** (Fase 5).

Para detalles de arquitectura interna, estado de desarrollo y cómo correr el juego desde código, ver [CONTRIBUTING.md](CONTRIBUTING.md).

## Créditos

**Diseño y desarrollo: Leibnyz**

Desarrollado con asistencia de [Claude Code](https://claude.com/claude-code) (Anthropic) para code review, decisiones de arquitectura y pair programming.

## Licencia

© 2026 Leibnyz. Todos los derechos reservados.
