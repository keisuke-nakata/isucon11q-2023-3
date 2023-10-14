ALTER TABLE isu_condition ADD INDEX jia_isu_uuid_timestamp_desc_idx (jia_isu_uuid, timestamp DESC);
ALTER TABLE isu_condition ADD COLUMN condition_level CHAR(8) GENERATED ALWAYS AS (CASE
    WHEN LENGTH(`condition`) = 47 THEN 'info'
    WHEN LENGTH(`condition`) IN (48, 49) THEN 'warning'
    WHEN LENGTH(`condition`) = 50 THEN 'critical'
    END) STORED;
