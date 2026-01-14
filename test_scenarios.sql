-- Test Scenarios

-- 1. Create a Tree
SET @tree_id = 0;
CALL sp_create_tree('Organization Chart', 'Main Org Chart', @tree_id);
SELECT * FROM trees WHERE id = @tree_id;

-- 2. Add Root Node
SET @root_id = 0;
CALL sp_add_node(
    @tree_id, 
    NULL, -- parent_id
    '{"name": "CEO"}', 
    'AS_LEAF', 
    NULL, 
    @root_id
);
SELECT * FROM nodes WHERE id = @root_id;

-- 3. Add Child Node (CTO)
SET @cto_id = 0;
CALL sp_add_node(@tree_id, @root_id, '{"name": "CTO"}', 'AS_LEAF', NULL, @cto_id);
SELECT * FROM nodes WHERE id = @cto_id;

-- 4. Add Child Node (CFO)
SET @cfo_id = 0;
CALL sp_add_node(@tree_id, @root_id, '{"name": "CFO"}', 'AS_LEAF', NULL, @cfo_id);

-- 5. Insert VP of Engineering BETWEEN CTO and Root? (Actually logic implies BETWEEN Parent and Sibling)
-- Let's test insert AS_LEAF for a grandchild
SET @eng_mgr_id = 0;
CALL sp_add_node(@tree_id, @cto_id, '{"name": "Eng Manager"}', 'AS_LEAF', NULL, @eng_mgr_id);

-- 6. Test INSERT_BETWEEN
-- Insert "VP Engineering" as child of CTO, and make "Eng Manager" child of "VP Engineering"
SET @vp_eng_id = 0;
CALL sp_add_node(
    @tree_id, 
    @cto_id, -- Parent: CTO
    '{"name": "VP Engineering"}', 
    'INSERT_BETWEEN', 
    @eng_mgr_id, -- Sibling/Child to take over: Eng Manager
    @vp_eng_id
);

SELECT 'After Insert Between check:';
SELECT * FROM nodes WHERE id = @vp_eng_id; -- Should have parent CTO
SELECT * FROM nodes WHERE id = @eng_mgr_id; -- Should have parent VP Eng

-- 7. Get Subordinates of CTO
CALL sp_get_subordinates(@cto_id);

-- 8. Get Path to Root for Eng Manager
CALL sp_get_path_to_root(@eng_mgr_id);

-- 9. Versioning
SET @new_version_id = 0;
CALL sp_new_node_version(@vp_eng_id, '{"name": "SVP Engineering"}', @new_version_id);

SELECT 'New Version Created:';
SELECT * FROM nodes WHERE id = @new_version_id; -- Should be active
SELECT * FROM nodes WHERE id = @vp_eng_id; -- Should be inactive

-- Check if Eng Manager is now child of New SVP
SELECT * FROM nodes WHERE id = @eng_mgr_id;
