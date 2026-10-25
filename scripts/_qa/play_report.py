#!/usr/bin/env python3
"""Agrega el log de partidas y dice qué métricas están rotas.

El juego deja una línea JSON por evento en `user://plays/*.jsonl`. Este
script las lee y saca las ocho métricas que deciden si la dificultad está
bien — las del plan `odd/tasks/learning-path-and-difficulty.md`, Parte B.

Sin datos, ajustar la dificultad es una opinión. Con este script es un
cálculo: cada métrica rota señala UN knob (el plan dice que nunca dos a
la vez, o se pierde la causalidad).

Uso:
    python3 scripts/_qa/play_report.py                     # user://plays/
    python3 scripts/_qa/play_report.py otro.jsonl          # un archivo
    python3 scripts/_qa/play_report.py --strict             # sale != 0 si algo rompe

El directorio `user://plays/` del Godot está en:
    ~/Library/Application Support/Godot/app_userdata/<proyecto>/plays/
"""

import json
import math
import os
import sys
from collections import defaultdict

# El plan de aprendizaje: cada challenge es el ejercicio de un capítulo.
CHAPTERS = {
    "main_exit_check": 1,
    "linear_search": 2,
    "factorial": 3,
    "binary_search": 4,
    "bubble_sort": 5,
    "use_std_sort": 5,
    "hash_map": 6,
    "fibonacci": 7,
    "simple_dp": 7,
    "template_generic": 8,
    "thread_join": 8,
    "final_gate": 9,
}

# La mediana de intentos al primer acierto que se tolera, por capítulo.
MAX_ATTEMPTS = {1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4}
MIN_FIRST_TRY_RATE = 0.60      # el primer intento tiene que funcionar
MAX_DEATH_RATE = 0.35          # muertes por enemigo
MAX_LEVEL_DEATH_SHARE = 0.25   # muertes de un tramo sobre el total del nivel
MAX_BATTLE_MS = 3 * 60 * 1000  # tres minutos por pelea
MIN_COMPLETED_RATE = 0.80      # capítulos completados de los que empiezan
TREE_XP_TOTAL = 5850           # el árbol entero cuesta 5850 XP

# Los carpetas de user:// según la plataforma.
USER_DIRS = [
    "~/Library/Application Support/Godot/app_userdata",
    "~/.local/share/godot/app_userdata",
    "~/AppData/Roaming/Godot/app_userdata",
]


def find_default_dir():
    for base in USER_DIRS:
        base = os.path.expanduser(base)
        if not os.path.isdir(base):
            continue
        for project in os.listdir(base):
            plays = os.path.join(base, project, "plays")
            if os.path.isdir(plays):
                return plays
    return None


def load_events(paths):
    events = []
    for path in paths:
        with open(path, "r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return events


def median(values):
    if not values:
        return None
    ordered = sorted(values)
    mid = len(ordered) // 2
    if len(ordered) % 2:
        return float(ordered[mid])
    return (ordered[mid - 1] + ordered[mid]) / 2.0


class Report:
    def __init__(self):
        self.rows = []
        self.broken = 0

    def metric(self, name, value, ok, threshold, action):
        self.rows.append((name, value, threshold, ok, action))
        if not ok:
            self.broken += 1
        return ok


def _battle_of(key, rows, battles):
    """El battle_start de la pelea a la que pertenecen estos intentos."""
    battle_id = rows[0].get("battle_id") if rows else None
    if battle_id is not None:
        for start in battles.values():
            if start.get("battle_id") == battle_id:
                return start
    enemy = rows[0].get("enemy_id") if rows else None
    if enemy and enemy in battles:
        return battles[enemy]
    return {}


def _challenge_of(key, rows, battles):
    if rows:
        challenge = rows[0].get("challenge_id")
        if challenge:
            return challenge
    return _battle_of(key, rows, battles).get("challenge_id", "?")


def analyze(events):
    report = Report()

    battles = {}       # enemy_id -> battle_start
    attempts = defaultdict(list)   # enemy_id -> filas de intento
    deaths = defaultdict(int)
    battles_by_enemy = defaultdict(int)
    level_deaths = defaultdict(int)
    battle_end = []
    skills = []
    levels_started = defaultdict(int)
    levels_completed = defaultdict(int)
    deaths_by_x = defaultdict(int)
    xp_by_enemy = defaultdict(int)

    for event in events:
        name = event.get("event")
        if name == "battle_start":
            enemy = event.get("enemy_id", "?")
            battles[enemy] = event
            battles_by_enemy[enemy] += 1
            xp_by_enemy[enemy] += int(event.get("xp", 0))
        elif name == "battle_attempt":
            # La pelea, no el enemigo: dos peleas contra el mismo enemigo
            # son dos mediciones.
            key = event.get("battle_id", 0) or event.get("enemy_id", "?")
            attempts[key].append(event)
        elif name == "battle_end":
            battle_end.append(event)
        elif name == "player_death":
            level_deaths[event.get("level_id", "?")] += 1
            deaths[event.get("cause", "?")] += 1
            deaths_by_x[int(event.get("x", 0)) // 50 * 50] += 1
        elif name == "skill_unlocked":
            skills.append(event)
        elif name == "level_start":
            levels_started[event.get("level_id", "?")] += 1
        elif name == "level_complete":
            if event.get("completed"):
                levels_completed[event.get("level_id", "?")] += 1

    # --- 1. intentos al primer acierto, por challenge ---------------------
    by_challenge = defaultdict(list)
    for enemy, rows in attempts.items():
        challenge = battles.get(enemy, {}).get("challenge_id", "?")
        by_challenge[challenge].append(rows)

    first_try_rates = {}
    attempt_table = []
    for challenge, fights in sorted(by_challenge.items(), key=lambda kv: CHAPTERS.get(kv[0], 99)):
        attempts_to_first = []
        first_try_hits = 0
        for rows in fights:
            success = next((r for r in rows if r.get("passed", 0) == r.get("total", 0)
                            and r.get("total", 0) > 0), None)
            if success is None:
                continue
            attempts_to_first.append(rows.index(success) + 1)
            if rows[0].get("passed", 0) == rows[0].get("total", 0) and rows[0].get("total", 0) > 0:
                first_try_hits += 1
        if not attempts_to_first:
            continue
        med = median(attempts_to_first)
        rate = first_try_hits / len(fights)
        chapter = CHAPTERS.get(challenge)
        threshold = MAX_ATTEMPTS.get(chapter, 3)
        first_try_rates[challenge] = rate
        attempt_table.append((challenge, chapter, med, threshold, rate, len(fights)))

    for challenge, chapter, med, threshold, rate, fights in attempt_table:
        report.metric(
            "intentos al primer acierto (%s)" % challenge,
            "%.1f" % med,
            med is not None and med <= threshold,
            "<= %d (cap %s)" % (threshold, chapter),
            "bajar difficulty o ast_required_features del challenge",
        )
        report.metric(
            "primer intento exitoso (%s)" % challenge,
            "%.0f%%" % (rate * 100),
            rate >= MIN_FIRST_TRY_RATE,
            ">= 60%",
            "el concepto no se enseno: un challenge mas chico antes",
        )

    # --- 2. muertes por enemigo --------------------------------------------
    for enemy, count in sorted(battles_by_enemy.items()):
        rate = deaths.get("battle", 0) / count if count else 0.0
        report.metric(
            "muertes por enemigo (%s)" % enemy,
            "%.0f%%" % (rate * 100),
            rate <= MAX_DEATH_RATE,
            "<= 35%%",
            "bajar max_hp o el dano del challenge",
        )

    # --- 3. muertes por tramo del nivel -----------------------------------
    total_deaths = sum(level_deaths.values())
    for level, count in sorted(level_deaths.items()):
        share = count / total_deaths if total_deaths else 0.0
        report.metric(
            "muertes concentradas (%s)" % level,
            "%.0f%%" % (share * 100),
            share <= MAX_LEVEL_DEATH_SHARE,
            "<= 25% del total",
            "agrandar el hueco o mover el top del span",
        )
    if deaths_by_x:
        hottest = max(deaths_by_x.items(), key=lambda kv: kv[1])
        report.rows.append((
            "tramo mas mortal (x~%d)" % hottest[0], "%d muertes" % hottest[1],
            "informativo", True, "mover el suelo de ese tramo",
        ))

    # --- 4. turnos para matar vs. el modelo de dano ------------------------
    for key, rows in sorted(attempts.items(), key=lambda kv: str(kv[0])):
        start = _battle_of(key, rows, battles)
        enemy = start.get("enemy_id", "?")
        hp = int(start.get("hp", 0))
        damage = [r.get("damage", 0) for r in rows if r.get("damage", 0) > 0]
        if hp <= 0 or not damage:
            continue
        average = sum(damage) / len(damage)
        predicted = math.ceil(hp / average) if average > 0 else 0
        observed = sum(1 for r in rows if r.get("damage", 0) > 0)
        report.metric(
            "turnos para matar (%s)" % enemy,
            "%d (modelo: %d)" % (observed, predicted),
            abs(observed - predicted) <= 1,
            "modelo +-1",
            "el modelo de dano no predice la realidad: recalibrar",
        )

    # --- 5. XP del capitulo ------------------------------------------------
    earned = sum(xp_by_enemy.values())
    report.rows.append((
        "XP ganada en las batallas", "%d" % earned,
        "el arbol entero cuesta %d" % TREE_XP_TOTAL, True,
        "si no alcanza, ajustar xp_reward o la curva de niveles",
    ))

    # --- 6. tiempo por pelea ------------------------------------------------
    times = [int(e.get("elapsed_ms", 0)) for e in battle_end if e.get("elapsed_ms")]
    if times:
        worst = max(times)
        report.metric(
            "tiempo por pelea (peor)",
            "%.0f s" % (worst / 1000.0),
            worst <= MAX_BATTLE_MS,
            "<= 180 s",
            "el challenge es largo demais: partirlo en dos",
        )

    # --- 7. capitulos completados -------------------------------------------
    started = sum(levels_started.values())
    completed = sum(levels_completed.values())
    if started:
        rate = completed / started
        report.metric(
            "capitulos completados",
            "%.0f%% (%d de %d)" % (rate * 100, completed, started),
            rate >= MIN_COMPLETED_RATE,
            ">= 80%",
            "mirar la plataforma, no el codigo",
        )
    else:
        report.rows.append((
            "capitulos completados", "sin datos", ">= 80%", True,
            "el nivel 01 todavia no tiene meta: cuando la tenga, el dato aparece",
        ))

    return report, attempts, battles, battle_end


def main():
    argv = sys.argv[1:]
    strict = "--strict" in argv
    argv = [a for a in argv if a != "--strict"]

    if argv:
        paths = argv
    else:
        default = find_default_dir()
        if default is None:
            print("No se encontro el directorio de partidas. Usa el boton")
            print("EXPORTAR DATOS DE JUEGO de las opciones y pasa el archivo.")
            return 0
        paths = [os.path.join(default, n) for n in sorted(os.listdir(default))
                 if n.endswith(".jsonl")]
        if not paths:
            print("No hay partidas registradas todavia.")
            return 0

    events = load_events(paths)
    if not events:
        print("Los archivos no tienen eventos.")
        return 0

    report, attempts, battles, battle_end = analyze(events)

    print("=" * 72)
    print("REPORTE DE JUGABILIDAD  (%d eventos, %d archivos)" % (len(events), len(paths)))
    print("=" * 72)
    for name, value, threshold, ok, action in report.rows:
        mark = "OK  " if ok else "ROTO"
        print("[%s] %-44s %-18s (umbral: %s)" % (mark, name, value, threshold))
        if not ok:
            print("        -> %s" % action)
    print("-" * 72)
    print("metricas rotas: %d de %d" % (report.broken, len(report.rows)))
    if strict and report.broken:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
