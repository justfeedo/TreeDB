-- Database Schema for Tree Structures

DROP TABLE IF EXISTS nodes;
DROP TABLE IF EXISTS trees;

-- 1. Tabulka se seznamem stromů
CREATE TABLE trees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    node_count INT DEFAULT 0 COMMENT 'Total number of active nodes',
    leaf_count INT DEFAULT 0 COMMENT 'Total number of active leaf nodes'
);

-- 2. Tabulka uzlů
CREATE TABLE nodes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tree_id INT NOT NULL,
    parent_id INT DEFAULT NULL,
    
    -- Structure Flags
    is_root BOOLEAN DEFAULT FALSE,
    is_leaf BOOLEAN DEFAULT TRUE,
    
    -- Versioning
    version INT DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE COMMENT 'False if node is invalidated or superseded by new version',
    
    -- Content
    data JSON,
    
    -- Foreign Keys
    CONSTRAINT fk_tree FOREIGN KEY (tree_id) REFERENCES trees(id) ON DELETE CASCADE,
    CONSTRAINT fk_parent FOREIGN KEY (parent_id) REFERENCES nodes(id) ON DELETE CASCADE,
    
    -- Indexes for performance
    INDEX idx_tree (tree_id),
    INDEX idx_parent (parent_id)
);

DELIMITER //

-- Triggers removed to prevent MySQL Error 1442 (Can't update table 'nodes' in stored function/trigger)
-- Logic for maintaining node_count, leaf_count, and is_leaf flags is now handled in Stored Procedures.

DELIMITER ;
