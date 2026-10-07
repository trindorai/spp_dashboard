-- Proper fix for teleport-object crash (Spell::EffectTeleportUnits null caster when target_orientation = 0).
-- Gives the affected teleport destinations a tiny non-zero facing so the crashing code path is skipped,
-- then re-enables the Surface Portal. Apply with the world server STOPPED (or restart after).
USE wotlkmangos;
UPDATE spell_target_position SET target_orientation = 0.01 WHERE target_orientation = 0 AND id IN (60905, 21128, 28444, 66899, 68328, 70606, 17278, 39217);
SELECT ROW_COUNT() AS destinations_fixed;
UPDATE gameobject SET spawnMask = 1 WHERE guid = 512443;
SELECT guid, id, map, spawnMask FROM gameobject WHERE guid = 512443;
SELECT id, target_map, target_orientation FROM spell_target_position WHERE id IN (60905, 21128, 28444, 66899, 68328, 70606, 17278, 39217);
