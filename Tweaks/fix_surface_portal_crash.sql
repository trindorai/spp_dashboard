-- Fix crash loop: bots using 'Surface Portal' (gameobject guid 512443, entry 193952, Northrend underground)
-- crash in Spell::EffectTeleportUnits. Run while world server is STOPPED (database still running).
USE wotlkmangos;
-- 1) Disable the portal spawn (revert: SET spawnMask = 1)
UPDATE gameobject SET spawnMask = 0 WHERE guid = 512443;
SELECT guid, id, map, spawnMask FROM gameobject WHERE guid = 512443;
USE wotlkcharacters;
-- 2) Move any offline characters stuck in that underground area to Dalaran
SELECT guid, name, level, position_x, position_y, position_z FROM characters WHERE map = 571 AND position_x BETWEEN 5650 AND 5950 AND position_y BETWEEN 1900 AND 2250 AND position_z < -250;
UPDATE characters SET position_x = 5804.15, position_y = 624.77, position_z = 647.77, zone = 4395 WHERE map = 571 AND online = 0 AND position_x BETWEEN 5650 AND 5950 AND position_y BETWEEN 1900 AND 2250 AND position_z < -250;
SELECT ROW_COUNT() AS characters_moved;
