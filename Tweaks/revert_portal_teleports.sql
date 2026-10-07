USE wotlkmangos;
UPDATE spell_target_position SET target_orientation = 0 WHERE target_orientation BETWEEN 0.005 AND 0.015 AND id IN (60905, 21128, 28444, 66899, 68328, 70606, 17278, 39217);
