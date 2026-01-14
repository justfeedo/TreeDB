# MySQL Tree Database

Toto je referenční implementace databázového schématu a uložených procedur pro správu hierarchických (stromových) struktur v MySQL.

Projekt řeší časté problémy při práci se stromy v relačních databázích:
- **Verzování**: Udržování historie změn jednotlivých uzlů.
- **Prevence cyklů**: Zamezení nekonečným smyčkám při přesunech uzlů.
- **Efektivní dotazování**: Použití Recursive CTE pro rychlé získání podstromů a cest ke kořeni.

## Obsah
- **`schema.sql`**: Definice tabulek `trees` a `nodes`.
- **`procedures.sql`**: Uložené procedury pro manipulaci s daty (Create, Add, Move, Remove, Version).
- **`DOCUMENTATION.md`**: Detailní popis všech procedur a tabulek.

## Rychlý Start

### Prerekvizity
- MySQL 8.0 nebo novější (vyžaduje podporu Recursive CTE).

### Instalace
Můžete použít přiložený skript pro Windows:
```cmd
run_local_verification.bat
```

Nebo manuálně importovat soubory:
```sql
source schema.sql;
source procedures.sql;
```

## Použití
Příklad vytvoření stromu a přidání uzlu:
```sql
CALL sp_create_tree('Main Tree', @tree_id);
CALL sp_add_node(@tree_id, NULL, '{"name": "Root"}', 'LEAF', NULL, @root_id);
```

Více příkladů naleznete v `DOCUMENTATION.md` a `test_script.sql`.

## Licence
MIT License.
