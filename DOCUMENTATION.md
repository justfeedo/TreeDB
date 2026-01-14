# Dokumentace MySQL Stromové Databáze

Tento dokument slouží jako detailní reference pro implementaci stromové struktury v MySQL. Popisuje databázové schéma, uložené procedury a klíčové koncepty jako verzování a detekci cyklů.

## 1. Schéma Databáze

### Tabulky

#### `trees` (Stromy)
Uchovává metadata pro každou stromovou strukturu.
| Sloupec | Typ | Popis |
| :--- | :--- | :--- |
| `id` | INT (PK) | Unikátní identifikátor stromu. |
| `name` | VARCHAR(255) | Název stromu. |
| `created_at` | DATETIME | Datum vytvoření. |
| `node_count` | INT | Cachovaný počet aktivních uzlů ve stromu (udržováno procedurami). |
| `leaf_count` | INT | Cachovaný počet aktivních listů (uzlů bez dětí). |

#### `nodes` (Uzly)
Reprezentuje hierarchické prvky (uzly) uvnitř stromu.
| Sloupec | Typ | Popis |
| :--- | :--- | :--- |
| `id` | INT (PK) | Unikátní identifikátor uzlu. |
| `tree_id` | INT (FK) | Odkaz na tabulku `trees`. |
| `parent_id` | INT (FK) | Odkaz na nadřazený uzel (NULL pro kořen/root). |
| `is_root` | BOOLEAN | Příznak, zda jde o kořenový uzel. |
| `is_leaf` | BOOLEAN | Příznak, zda uzel nemá žádné aktivní potomky (list). |
| `version` | INT | Číslo verze uzlu (začíná na 1). |
| `is_active` | BOOLEAN | `TRUE` pokud je uzel aktuální, `FALSE` pokud byl smazán nebo nahrazen novou verzí. |
| `data` | JSON | Obsah/data uzlu (např. vlastnosti, nastavení). |

### Integrita Dat
Původní návrh počítal s Triggery pro údržbu počtů (`node_count`). Kvůli omezení MySQL (chyba rekurze při update stejné tabulky) byla tato logika přesunuta přímo do **Uložených Procedur**.
Procedury automaticky:
- Navyšují/snižují `node_count`.
- Aktualizují příznak `is_leaf` u rodičovských uzlů.

---

## 2. Uložené Procedury (Stored Procedures)

### Vytváření a Správa

#### `sp_create_tree(p_name, OUT p_tree_id)`
Vytvoří novou definici stromu.
- **Vstup**: `p_name` (Název stromu).
- **Výstup**: `p_tree_id` (ID nového stromu).

#### `sp_add_node(p_tree_id, p_parent_id, p_data, p_mode, p_child_id, OUT p_node_id)`
Přidá nový uzel do stromu.
- **Režimy** (`p_mode`):
    - `'LEAF'`: Přidá uzel jako potomka `p_parent_id`.
    - `'BETWEEN'`: Vloží uzel **mezi** `p_parent_id` a jeho děti.
        - Pokud je zadáno `p_child_id`, vloží se pouze mezi rodiče a toto specifické dítě.
        - Pokud je `p_child_id` NULL, vloží se mezi rodiče a *všechny* jeho stávající děti.
- **Výstup**: `p_node_id` (ID nového uzlu).

### Mazání a Zneplatnění

#### `sp_remove_node(p_node_id)`
Provede **tvrdé smazání** (hard delete) uzlu z databáze.
- **Pozor**: Smazání uzlu smaže i všechny jeho potomky (díky `ON DELETE CASCADE` v databázi).

#### `sp_invalidate_node(p_node_id)`
Provede **logické smazání** nastavením `is_active = FALSE`.
- Procedura také aktualizuje počítadla stromu.

### Verzování (Versioning)

#### `sp_create_node_version(p_node_id, p_new_data, OUT p_new_node_id)`
Vytvoří novou verzi existujícího uzlu při zachování hierarchie.
1. Označí starý uzel (`p_node_id`) jako neaktivní.
2. Vytvoří nový uzel s `version = stará_verze + 1` a novými daty.
3. **Přesune všechny děti** ze starého uzlu na nový.
4. Vrací ID nové verze.

### Průchod Stromem (Rekurzivní)

#### `sp_get_path_to_root(p_node_id)`
Vrátí celou linii nadřízených prvků od daného uzlu až ke kořeni.
- **Výsledek**: Seznam uzlů seřazený podle vzdálenosti vzestupně.

#### `sp_get_subordinate_elements(p_node_id)`
Vrátí kompletní podstrom (všechny potomky) daného uzlu.
- **Výsledek**: Seznam všech uzlů hierarchicky pod `p_node_id`.

### Strukturální Změny

#### `sp_move_node(p_node_id, p_new_parent_id)`
Přesune existující uzel pod nového rodiče.
- **Detekce Cyklů**: Před přesunem kontroluje, zda `p_new_parent_id` není potomkem přesouvaného uzlu. Pokud by přesun způsobil zacyklení, procedura vyhodí chybu.

---

## 3. Příklady Použití

### Vytvoření Stromu
```sql
CALL sp_create_tree('Organizační Struktura', @tree_id);
```

### Budování Hierarchie
```sql
-- Přidání Kořene (CEO)
CALL sp_add_node(@tree_id, NULL, '{"role": "CEO"}', 'LEAF', NULL, @root_id);

-- Přidání Potomka (CTO)
CALL sp_add_node(@tree_id, @root_id, '{"role": "CTO"}', 'LEAF', NULL, @cto_id);
```

### Verzování Uzlu
```sql
-- Povýšení CTO na "New CTO" (děti zůstávají zachovány pod ním)
CALL sp_create_node_version(@cto_id, '{"role": "New CTO"}', @new_cto_id);
```

### Dotazování
```sql
-- Získání všech podřízených pod CEO
CALL sp_get_subordinate_elements(@root_id);

-- Získání nadřízených pro CTO (Managerial Chain)
CALL sp_get_path_to_root(@cto_id);
```

---

## 4. K čemu se taková databáze hodí?

Tento typ hierarchické (stromové) databáze s verzováním je ideální pro situace, kde je struktura dat stejně důležitá jako data samotná:

1.  **Organizační struktury firem**: Evidence zaměstnanců, oddělení a jejich nadřízenosti. Díky verzování můžete vidět historii změn (kdo byl šéfem loni).
2.  **Kategorizace produktů (E-shopy)**: Hluboké stromy kategorií (Elektronika -> Počítače -> Notebooky -> Herní). Funkce `sp_move_node` umožňuje snadno přesouvat celé větve kategorií.
3.  **Systémy správy dokumentů (DMS)**: Složky a podsložky. Verzování uzlů umožňuje uchovávat historii změn metadat složek.
4.  **Multi-level Marketing (MLM)**: Sledování stromu doporučení a provizí, kde je kritické vědět, kdo je pod kým a předcházet cyklům.
5.  **Kusovníky ve výrobě (BOM - Bill of Materials)**: Auto se skládá z Motoru, Motor z Válců atd. `sp_get_subordinate_elements` umožní "rozpadnout" výrobek na prvočinitele.
