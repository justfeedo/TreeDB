-- Test Script for MySQL Tree Database
-- Use this script to verify the functionality of schema.sql and procedures.sql

-- Setup (handled by batch script)
-- source schema.sql;
-- source procedures.sql;

-- 1. Create a Tree
CALL sp_create_tree('My Organization Chart', @tree_id);
SELECT @tree_id as TreeID;

-- 2. Add Root Node (CEO)
CALL sp_add_node(@tree_id, NULL, '{"name": "CEO", "role": "root"}', 'LEAF', NULL, @root_id);
SELECT @root_id as RootID;

-- 3. Add Children to Root (CTO, CFO)
CALL sp_add_node(@tree_id, @root_id, '{"name": "CTO"}', 'LEAF', NULL, @cto_id);
CALL sp_add_node(@tree_id, @root_id, '{"name": "CFO"}', 'LEAF', NULL, @cfo_id);

-- 4. Add Child to CTO (Dev Manager)
CALL sp_add_node(@tree_id, @cto_id, '{"name": "Dev Manager"}', 'LEAF', NULL, @dev_mgr_id);

-- 5. Insert "VP of Engineering" BETWEEN CEO and CTO
-- This should result in CEO -> VP Eng -> CTO
CALL sp_add_node(@tree_id, @root_id, '{"name": "VP Engineering"}', 'BETWEEN', @cto_id, @vp_id);

-- Verify Structure Path for Dev Manager (Should be CEO -> VP -> CTO -> Dev Manager)
CALL sp_get_path_to_root(@dev_mgr_id);

-- 6. Test Cycle Detection (Try to move CEO to under Dev Manager)
-- Expected: Error 'Cycle detected...'
-- CALL sp_move_node(@root_id, @dev_mgr_id); 

-- 7. Versioning: Create new version of CFO (Promoted to Chief Finance & Ops Officer)
CALL sp_create_node_version(@cfo_id, '{"name": "CFOO", "role": "expanded"}', @new_cfo_id);

-- Verify old CFO is inactive and new CFO exists and is child of CEO
SELECT id, data, is_active FROM nodes WHERE id IN (@cfo_id, @new_cfo_id);

-- 8. Get Subtree for CEO
CALL sp_get_subordinate_elements(@root_id);

-- 9. Remove a node (Dev Manager)
CALL sp_remove_node(@dev_mgr_id);

-- Check counts
SELECT * FROM trees WHERE id = @tree_id;
