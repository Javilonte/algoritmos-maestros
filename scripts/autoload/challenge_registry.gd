class_name ChallengeRegistry

## Registro global de challenges. Centraliza los ChallengeData
## para evitar depender de archivos .tres externos durante el slice.
## Accesible via ChallengeRegistry.fetch(id) (clase estatica pura).

const _CHALLENGES: Dictionary = {
	&"slime_aritm": {
		"display_name": "Suma Básica",
		"prompt": "Imprime la suma de 2 y 3 en una línea.\nSalida esperada: 5",
		"stdin": "",
		"expected_output": "5",
		"time_limit_sec": 2.0,
		"memory_limit_kb": 128000,
		"base_score": 10,
		"keyword_bonus": {"cout": 1.0, "+": 1.0, "int": 1.0},
		"hint_lines": [
			"cout << (2 + 3) << endl;",
			"O bien: cout << 5 << endl;",
		],
	},
	&"buggo_ciego": {
		"display_name": "Duplicar Número",
		"prompt": "Lee un entero N y luego imprime N*2.\nEjemplo: input '7' → output '14'",
		"stdin": "7\n",
		"expected_output": "14",
		"time_limit_sec": 2.0,
		"memory_limit_kb": 128000,
		"base_score": 15,
		"keyword_bonus": {"cin": 1.0, "cout": 1.0, "*": 1.0},
		"hint_lines": [
			"int n; cin >> n;",
			"cout << n * 2 << endl;",
		],
	},
	&"ogro_bucle": {
		"display_name": "Contar 1 a 5",
		"prompt": "Imprime los números del 1 al 5 separados por espacios en una sola línea.\nSalida esperada: 1 2 3 4 5",
		"stdin": "",
		"expected_output": "1 2 3 4 5",
		"time_limit_sec": 2.0,
		"memory_limit_kb": 128000,
		"base_score": 25,
		"keyword_bonus": {"for": 1.5, "while": 1.0, "cout": 1.0},
		"hint_lines": [
			"for (int i = 1; i <= 5; ++i) cout << i << ' ';",
			"cout << endl;",
		],
	},
	&"memory_leak": {
		"display_name": "Suma 1 a N",
		"prompt": "Lee un entero N y luego imprime la suma 1+2+...+N.\nEjemplo: input '5' → output '15'",
		"stdin": "5\n",
		"expected_output": "15",
		"time_limit_sec": 2.0,
		"memory_limit_kb": 128000,
		"base_score": 60,
		"keyword_bonus": {"delete": 2.0, "free": 1.5, "for": 1.0, "while": 1.0},
		"hint_lines": [
			"int n, s = 0; cin >> n;",
			"for (int i = 1; i <= n; ++i) s += i;",
			"cout << s << endl;",
		],
	},
}

static func fetch(id: StringName) -> ChallengeData:
	if not _CHALLENGES.has(id):
		return null
	var d: Dictionary = _CHALLENGES[id]
	var c := ChallengeData.new()
	c.id = id
	c.display_name = String(d.get("display_name", ""))
	c.prompt = String(d.get("prompt", ""))
	c.stdin = String(d.get("stdin", ""))
	c.expected_output = String(d.get("expected_output", ""))
	c.time_limit_sec = float(d.get("time_limit_sec", 2.0))
	c.memory_limit_kb = int(d.get("memory_limit_kb", 128000))
	c.base_score = int(d.get("base_score", 10))
	c.keyword_bonus = (d.get("keyword_bonus", {}) as Dictionary).duplicate()
	c.hint_lines = PackedStringArray(d.get("hint_lines", []) as Array)
	return c

static func has(id: StringName) -> bool:
	return _CHALLENGES.has(id)

static func all() -> Array:
	return _CHALLENGES.keys()