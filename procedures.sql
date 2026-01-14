-- stored procedures.sql

DELIMITER //

-- 1. Vytvoření nového stromu
DROP PROCEDURE IF EXISTS sp_create_tree //
CREATE PROCEDURE sp_create_tree(
    IN p_name VARCHAR(255),
    OUT p_tree_id INT
)
BEGIN
    INSERT INTO trees (name) VALUES (p_name);
    SET p_tree_id = LAST_INSERT_ID();
END //

-- 2. Přidání uzlu do stromu
-- Modes: 'LEAF' (default), 'BETWEEN'
-- If BETWEEN, it puts the new node between p_parent_id and its children.
-- p_child_id: Optional, if inserting between parent and a SPECIFIC child.
DROP PROCEDURE IF EXISTS sp_add_node //
CREATE PROCEDURE sp_add_node(
    IN p_tree_id INT,
    IN p_parent_id INT,
    IN p_data JSON,
    IN p_mode VARCHAR(20), 
    IN p_child_id INT,
    OUT p_node_id INT
)
BEGIN
    DECLARE v_new_id INT;

    -- Basic Validation
    IF p_parent_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM nodes WHERE id = p_parent_id AND tree_id = p_tree_id AND is_active = TRUE) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Parent node not found or inactive';
        END IF;
    END IF;

    -- Insert the new node
    INSERT INTO nodes (tree_id, parent_id, data, is_root, is_leaf)
    VALUES (p_tree_id, p_parent_id, p_data, (p_parent_id IS NULL), TRUE);
    
    SET v_new_id = LAST_INSERT_ID();
    SET p_node_id = v_new_id;

    -- Maintain Counters & Flags (was in Triggers)
    UPDATE trees SET node_count = node_count + 1 WHERE id = p_tree_id;
    
    IF p_parent_id IS NOT NULL THEN
        UPDATE nodes SET is_leaf = FALSE WHERE id = p_parent_id;
    ELSE
        -- Root added, increment leaf count (it is a leaf initially)
        UPDATE trees SET leaf_count = leaf_count + 1 WHERE id = p_tree_id;
    END IF;

    -- Handle INSERT BETWEEN
    IF p_parent_id IS NOT NULL AND p_mode = 'BETWEEN' THEN
        IF p_child_id IS NOT NULL THEN
             -- Specific child re-parenting
             UPDATE nodes SET parent_id = v_new_id WHERE id = p_child_id AND parent_id = p_parent_id;
        ELSE
             -- All children re-parenting
             UPDATE nodes SET parent_id = v_new_id WHERE parent_id = p_parent_id AND id != v_new_id;
        END IF;
        
        -- Since we adopted children, we are not a leaf
        UPDATE nodes SET is_leaf = FALSE WHERE id = v_new_id;
    END IF;
END //

-- 3. Odstranění uzlu (Physical Delete)
DROP PROCEDURE IF EXISTS sp_remove_node //
CREATE PROCEDURE sp_remove_node(
    IN p_node_id INT
)
BEGIN
    DECLARE v_tree_id INT;
    DECLARE v_parent_id INT;
    DECLARE v_parent_has_children INT;

    SELECT tree_id, parent_id INTO v_tree_id, v_parent_id FROM nodes WHERE id = p_node_id;

    DELETE FROM nodes WHERE id = p_node_id;
    
    -- Maintain Counters
    IF v_tree_id IS NOT NULL THEN
        UPDATE trees SET node_count = GREATEST(0, node_count - 1) WHERE id = v_tree_id;
        
        -- Check if parent became a leaf
        IF v_parent_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_parent_has_children FROM nodes WHERE parent_id = v_parent_id AND is_active = TRUE;
            IF v_parent_has_children = 0 THEN
                UPDATE nodes SET is_leaf = TRUE WHERE id = v_parent_id;
            END IF;
        END IF;
    END IF;
END //

-- 4. Zneplatnění uzlu (Logical Delete)
DROP PROCEDURE IF EXISTS sp_invalidate_node //
CREATE PROCEDURE sp_invalidate_node(
    IN p_node_id INT
)
BEGIN
    DECLARE v_tree_id INT;
    DECLARE v_parent_id INT;
    DECLARE v_parent_has_children INT;
    
    SELECT tree_id, parent_id INTO v_tree_id, v_parent_id FROM nodes WHERE id = p_node_id;

    UPDATE nodes SET is_active = FALSE WHERE id = p_node_id;
    
    -- Maintain Counters
    IF v_tree_id IS NOT NULL THEN
        UPDATE trees SET node_count = GREATEST(0, node_count - 1) WHERE id = v_tree_id;
        
        -- Check if parent became a leaf
        IF v_parent_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_parent_has_children FROM nodes WHERE parent_id = v_parent_id AND is_active = TRUE;
            IF v_parent_has_children = 0 THEN
                UPDATE nodes SET is_leaf = TRUE WHERE id = v_parent_id;
            END IF;
        END IF;
    END IF;
END //

-- 2b. Nová verze uzlu (Versioning)
-- Creates a new node with incremented version, moves children to it, marks old as inactive.
DROP PROCEDURE IF EXISTS sp_create_node_version //
CREATE PROCEDURE sp_create_node_version(
    IN p_node_id INT,
    IN p_new_data JSON,
    OUT p_new_node_id INT
)
BEGIN
    DECLARE v_tree_id INT;
    DECLARE v_parent_id INT;
    DECLARE v_old_version INT;
    DECLARE v_new_id INT;
    DECLARE v_parent_has_children INT;
    
    SELECT tree_id, parent_id, version INTO v_tree_id, v_parent_id, v_old_version 
    FROM nodes WHERE id = p_node_id;
    
    IF v_tree_id IS NULL THEN
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Node not found';
    END IF;
    
    -- Invalidate old
    UPDATE nodes SET is_active = FALSE WHERE id = p_node_id;
    
    -- Counters: Invalidation effectively removes 1 active node
    UPDATE trees SET node_count = GREATEST(0, node_count - 1) WHERE id = v_tree_id;
    
    -- Create new
    INSERT INTO nodes (tree_id, parent_id, data, version, is_root, is_leaf)
    VALUES (v_tree_id, v_parent_id, p_new_data, v_old_version + 1, (v_parent_id IS NULL), TRUE);
    
    SET v_new_id = LAST_INSERT_ID();
    SET p_new_node_id = v_new_id;
    
    -- Counters: New node is created
    UPDATE trees SET node_count = node_count + 1 WHERE id = v_tree_id;
    
    -- New node is a leaf initially (unless children moved), Parent already has children (the old node was child) so parent.is_leaf doesn't change yet?
    -- Actually, we invalidated the old child. So we must check parent state?
    -- No, simpler: We are replacing one active child with another active child immediately.
    -- The parent's is_leaf status shouldn't change in net effect, BUT because we do it in steps, it might toggle.
    -- However, since parent_id is same, and we just added a NEW active child, parent is definitely NOT a leaf.
    IF v_parent_id IS NOT NULL THEN
        UPDATE nodes SET is_leaf = FALSE WHERE id = v_parent_id;
    END IF;
    
    -- Re-parent children from old to new
    UPDATE nodes SET parent_id = v_new_id WHERE parent_id = p_node_id;
    
    -- If we adopted children, we are not a leaf
    IF EXISTS (SELECT 1 FROM nodes WHERE parent_id = v_new_id) THEN
        UPDATE nodes SET is_leaf = FALSE WHERE id = v_new_id;
    END IF;
END //

-- 5. Zjištění cesty od daného prvku ke kořenu
DROP PROCEDURE IF EXISTS sp_get_path_to_root //
CREATE PROCEDURE sp_get_path_to_root(IN p_node_id INT)
BEGIN
    WITH RECURSIVE path_cte AS (
        SELECT id, parent_id, data, version, 0 as distance
        FROM nodes WHERE id = p_node_id
        UNION ALL
        SELECT n.id, n.parent_id, n.data, n.version, p.distance + 1
        FROM nodes n
        INNER JOIN path_cte p ON n.id = p.parent_id
    )
    SELECT * FROM path_cte ORDER BY distance ASC;
END //

-- 6. Vypsání všech podřízených prvků
DROP PROCEDURE IF EXISTS sp_get_subordinate_elements //
CREATE PROCEDURE sp_get_subordinate_elements(IN p_node_id INT)
BEGIN
    WITH RECURSIVE subtree_cte AS (
        SELECT id, parent_id, data, version, 0 as level
        FROM nodes WHERE id = p_node_id AND is_active = TRUE
        UNION ALL
        SELECT n.id, n.parent_id, n.data, n.version, s.level + 1
        FROM nodes n
        INNER JOIN subtree_cte s ON n.parent_id = s.id
        WHERE n.is_active = TRUE
    )
    SELECT * FROM subtree_cte WHERE id != p_node_id ORDER BY level, id;
END //

-- 7. Helper: Move Node / Check Cycle
-- Moves p_node_id to be a child of p_new_parent_id. Checks for cycles.
DROP PROCEDURE IF EXISTS sp_move_node //
CREATE PROCEDURE sp_move_node(IN p_node_id INT, IN p_new_parent_id INT)
BEGIN
    DECLARE v_is_ancestor INT DEFAULT 0;

    -- Cannot move to itself
    IF p_node_id = p_new_parent_id THEN
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot move node to itself';
    END IF;

    -- Check if p_node_id is an ancestor of p_new_parent_id
    -- (If we move Node A to be child of B, and A is currently ancestor of B, it creates a cycle)
    WITH RECURSIVE ancestors AS (
        SELECT parent_id FROM nodes WHERE id = p_new_parent_id
        UNION ALL
        SELECT n.parent_id FROM nodes n JOIN ancestors a ON n.id = a.parent_id
        WHERE n.parent_id IS NOT NULL
    )
    SELECT COUNT(*) INTO v_is_ancestor FROM ancestors WHERE parent_id = p_node_id;
    
    IF v_is_ancestor > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cycle detected: Cannot move node to one of its descendants';
    END IF;
    
    UPDATE nodes SET parent_id = p_new_parent_id WHERE id = p_node_id;
END //

DELIMITER ;
