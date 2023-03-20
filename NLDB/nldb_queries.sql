--HIGHLIGHTS
--1. Total runs, deaths, wins, and win rate by character, excluding forced resets and exiting the game
--Skills used: Subquery, CTE, SELECT INTO Temp Table, Type casting using ::, Aggregate Functions, Joins, Union All
		
	--Drop temp table if it already exists
	DROP TABLE IF EXISTS death_table

	--Create a temp table to group all runs that resulted in a death
	SELECT game_character, COUNT(run_number) as deaths
	INTO TEMP death_table
	FROM played_characters
	WHERE died_from IS NOT NULL
	AND died_from != 'ForcedReset'
	AND died_from != 'ExitedGame'
	AND latest = true
	GROUP BY game_character
	ORDER BY COUNT(run_number) DESC

	--Use CTE to get all winning and losing runs (excluding Forced Resets and Exited Game) grouped by character
	WITH runs_by_char (game_character, total_runs)
	AS
	(
		--Aggregate runs by character using subquery
		SELECT game_character, COUNT(run_number) AS total_runs
		FROM (
			--All winning runs
			SELECT game_character, run_number
			FROM played_characters
			WHERE latest = true
			AND died_from IS NULL
			UNION ALL
			--All losing runs, excluding FR and EG
			SELECT game_character, run_number
			FROM played_characters
			WHERE latest = true
			AND died_from != 'ForcedReset'
			AND died_from != 'ExitedGame'
		) char_runs
		GROUP BY game_character
		ORDER BY game_character
	)
	-- Select character, total runs, wins, losses, and win rate
	SELECT a.game_character, a.total_runs, b.deaths, (a.total_runs - b.deaths) as wins
	, ROUND((((a.total_runs::NUMERIC) - b.deaths)/a.total_runs), 3) * 100 AS win_rate
	FROM runs_by_char a
	JOIN death_table b
	ON a.game_character = b.game_character
	ORDER BY win_rate DESC


--2. Last floor of each winning run
--Skills used: Subquery, CTE, SELECT INTO Temp Table, CASE, PARTITION OVER, Aggregate Functions, CAST, Joins, Union All
	--Solution 1 Using gameplay_events
	SELECT resource_two, COUNT(resource_two) AS total_wins
	FROM gameplay_events 
	WHERE event_type = 16
	AND latest = true
	GROUP BY resource_two
	ORDER BY COUNT(resource_two) DESC

	--Solution 2 using only played_floors and temp table
	DROP TABLE IF EXISTS last_floors

	-- Create Temp table containing ending floor_number for each run
	SELECT MAX(id) AS id, played_character AS run_number, MAX(floor_number) AS floor_number
	INTO TEMP last_floors
	FROM played_floors
	WHERE latest = true
	GROUP BY played_character
	ORDER BY  played_character

	--Join to add name of floor and count of wins for each floor
	SELECT a.floor, COUNT(b.run_number) AS total_wins
	FROM played_floors a
	RIGHT JOIN last_floors b
	ON a.id = b.id
	WHERE died_from IS NULL
	GROUP BY a.floor
	ORDER BY total_wins DESC

	--Bonus: Last floor of each run, whether it was a win or a loss, a running total of number of wins win percentage
	WITH win_percent AS
	(
		-- Use CTE to calculate running wins and losses based of 'result' column created below.
		WITH win_losses AS
		(
			-- Use Join as in previous query to get the last floor of each run
			-- Use CASE to determine if run is Win or Loss based off 'died_from' column
			SELECT b.run_number, a.floor, b.floor_number
			, CASE
				WHEN a.died_from IS NULL THEN 'Win'
				WHEN a.died_from IS NOT NULL THEN 'Loss'
				END result
			FROM played_floors a
			RIGHT JOIN last_floors b
			ON a.id = b.id
		)
		-- Use Window Function to add running totals of Wins and total runs.
		SELECT *, SUM(CASE WHEN result = 'Win' THEN 1 ELSE 0 END) OVER (ORDER BY run_number) AS running_wins
		, COUNT(result) OVER (ORDER BY run_number) AS total_runs
		FROM win_losses
		ORDER BY run_number
	)
	-- Use CTE to calculate running win percentage based on running totals created above.
	SELECT *, TRUNC((CAST(running_wins AS DEC)/total_runs)*100, 2) AS win_percentage
	FROM win_percent


--3. Create a table that has the standard floors and floor order
--Skills used: SELECT INTO Table, CASE, DELETE
-- Allows me to easily filter out alternate game modes and group floors by the order they appear in game
-- floor_order actually represents a 'chapter' in-game. Chapters can be 1 or 2 floors or can have floors in between
-- This is why I wanted to make floor_order instead of relying on floor_number from played_floors table.
	DROP TABLE IF EXISTS standard_floors

	--Determine floor_order from Isaac Wiki
	SELECT floor, 
		CASE
			WHEN floor LIKE 'Basement%' OR floor LIKE 'Cellar%' OR floor LIKE 'BurningBase%' THEN 1
			WHEN floor LIKE 'Downpour%' OR floor LIKE 'Dross%' THEN 1.5
			WHEN floor LIKE 'Caves%' OR floor LIKE 'Catacombs%' OR floor LIKE 'Flooded%' OR floor LIKE 'Mines%' OR floor LIKE 'Ashpit%' THEN 2
			WHEN floor LIKE 'Depths%' OR floor LIKE 'Necropolis%' OR floor LIKE 'DankDepths%' OR floor LIKE 'Mausoleum%' OR floor LIKE 'Gehenna%' THEN 3
			WHEN floor LIKE 'Womb%' OR floor LIKE 'Utero%' OR floor LIKE 'Scarred%' OR floor = 'Home' THEN 4
			WHEN floor LIKE 'Blue%' OR floor LIKE 'Corpse%' THEN 4.5
			WHEN floor = 'Cathedral' OR floor = 'Sheol' OR floor = 'TheVoid' THEN 5
			WHEN floor = 'Chest' OR floor ='DarkRoom' THEN 6
		END AS floor_order
	INTO standard_floors
	FROM played_floors
	GROUP BY floor

	--Remove floors associated with alternate game modes
	DELETE FROM standard_floors
	WHERE floor LIKE 'Greed%' OR floor LIKE 'Arena%' OR floor LIKE 'Missing%'
	--Alternatively, drop floors not assigned a floor_order above
	DELETE FROM standard_floors
	WHERE floor_order IS NULL

--4. Use created standard_floor table to look at item pickup information from gameplay_events
--Skills used: SELECT INTO Temp Table, Multiple Joins
--Filter gameplay_events to relevant columns and only item pickup events
--Join played_floors and standard_floors to filter out alternate game modes
	DROP TABLE IF EXISTS item_pickups

	SELECT a.resource_one AS item_name, b.floor, c.floor_order, a.played_floor, a.played_character, a.was_rerolled, a.latest
	INTO TEMP item_pickups
	FROM gameplay_events a
	LEFT JOIN played_floors b
	ON a.played_floor = b.id
	LEFT JOIN standard_floors c
	ON b.floor = c.floor
	WHERE a.event_type = 2
	AND floor_order IS NOT NULL
	AND a.latest = true
	ORDER BY played_character

	SELECT *
	FROM item_pickups
	LIMIT 10

	--Example Query using above table
	--The infamous Mom's Knife item used as an example. Can be swapped out to view information about any item.
	--Frequency of Mom's Knife showing up by floor order
	SELECT floor_order, COUNT(item_name)
	FROM item_pickups
	WHERE item_name = 'MomsKnife'
	GROUP BY floor_order
	ORDER BY floor_order ASC

--FUN STUFF
	--Random Quote Generator
	SELECT content
	FROM quotes
	ORDER BY RANDOM()
	LIMIT 1

	-- Number of wins per day of the week (pretty evenly spread!)
	SELECT ('{Sun,Mon,Tue,Wed,Thu,Fri,Sat}'::text[])[EXTRACT(DOW FROM b.published)+1] AS day_of_week, COUNT(run_number) as wins
	FROM played_characters a
	JOIN videos b
	ON a.video = b.id
	WHERE died_from IS NULL
	AND latest = true
	GROUP BY day_of_week
	ORDER BY day_of_week
	
	--The videos where NL talked about cats
	SELECT topic, video
	FROM discussion_topics
	WHERE LOWER(topic) LIKE '% cat %' OR LOWER(topic) LIKE '% cats %' OR LOWER(topic) LIKE '%cat-%' OR LOWER(topic) LIKE '$feline%'
	UNION ALL
	SELECT content, video
	FROM quotes
	WHERE LOWER(content) LIKE '% cat %' OR LOWER(content) LIKE '% cats %' OR LOWER(content) LIKE '%cat-%' OR LOWER(content) LIKE '%feline'


--VIEWS
	-- Relevant Video Stats
	CREATE VIEW nldb_video_stats AS
	SELECT title, DATE(published), view_count, likes, duration/60 AS length_min
	FROM videos

--ALL QUERIES
-- VIDEO STATS
	--Most viewed video
	SELECT title, DATE(published), view_count
	FROM videos
	WHERE view_count = (SELECT MAX(view_count) FROM videos)

	--Most liked video (Same as above)
	SELECT title, DATE(published), likes
	FROM videos
	WHERE likes = (SELECT MAX(likes) FROM videos)	

	--Views per video
	SELECT title, DATE(published), view_count
	FROM videos
	ORDER BY DATE(published) ASC

	--Average views per video
	SELECT TRUNC(AVG(view_count),0) AS avg_views
	FROM videos

	--Average video length	
	SELECT TRUNC(AVG(duration)/60,2) AS minutes
	FROM videos

	--Total hours played
	SELECT SUM(duration)/3600 AS hours_played
	FROM videos

	--Number of episodes with multiple wins in the same video
	SELECT COUNT(*) AS multi_win_videos 
	FROM (
		SELECT submission, COUNT(run_number)
		FROM played_characters
		WHERE died_from IS NULL
		AND latest = true
		GROUP BY submission
		HAVING COUNT(run_number) > 1
	) multi_wins

	--Number of episodes with multiple losses in the same video
	SELECT COUNT(*) AS multi_loss_videos 
	FROM (
		SELECT submission, COUNT(run_number)
		FROM played_characters
		WHERE died_from IS NOT NULL
		AND latest = true
		GROUP BY submission
		HAVING COUNT(run_number) > 1
	) multi_losses

	--Number of episodes with multiple losses, exluding FR and exiting the game
	SELECT COUNT(*) AS multi_loss_videos 
	FROM (
		SELECT submission, COUNT(run_number)
		FROM played_characters
		WHERE died_from IS NOT NULL
		AND died_from != 'ForcedReset'
		AND died_from != 'ExitedGame'
		AND latest = true
		GROUP BY submission
		HAVING COUNT(run_number) > 1
	) multi_losses_no_fr

-- GAMEPLAY STATS
	--Deadliest enemies
	SELECT died_from, COUNT(died_from)
	FROM played_characters
	WHERE died_from IS NOT null
	AND latest = true
	GROUP BY died_from
	ORDER BY COUNT(died_from) DESC

	--Runs by character
	SELECT game_character, COUNT(game_character)
	FROM played_characters
	WHERE latest = true
	GROUP BY game_character
	ORDER BY COUNT (game_character) DESC

	--Number of force rests by character
	SELECT game_character, COUNT(run_number) as forced_resets
	FROM played_characters
	WHERE died_from = 'ForcedReset'
	AND latest = true
	GROUP BY game_character
	ORDER BY COUNT(run_number) DESC

	--Total deaths by character, excluding forced resets and exiting game
	SELECT game_character, COUNT(run_number) as deaths
	FROM played_characters
	WHERE died_from IS NOT NULL
	AND died_from != 'ForcedReset'
	AND died_from != 'ExitedGame'
	AND latest = true
	GROUP BY game_character
	ORDER BY COUNT(run_number) DESC

	--Total number of runs, total number of wins, total number of deaths excluding forced resets and exiting game
	--Total Runs
	SELECT COUNT(run_number)
	FROM (
		--winning runs
		SELECT run_number
		FROM played_characters
		WHERE latest = true
		AND died_from IS NULL
		UNION ALL
		-- losing runs, excluding FR and EG
		SELECT run_number
		FROM played_characters
		WHERE latest = true
		AND died_from != 'ForcedReset'
		AND died_from != 'ExitedGame'
	) no_fr

	--Total deaths
	SELECT COUNT(run_number) as deaths
	FROM played_characters
	WHERE died_from IS NOT NULL
	AND died_from != 'ForcedReset'
	AND died_from != 'ExitedGame'
	AND latest = true

	--Total wins
	SELECT COUNT(run_number) as wins
	FROM played_characters
	WHERE died_from IS NULL
	AND latest = true

	--Total encounters of each floor
	SELECT floor, COUNT(floor) AS number
	FROM played_floors
	GROUP BY floor
	ORDER BY COUNT(floor) DESC

--ITEMS
	--Number of winning runs with Mom's Knife
	SELECT COUNT(a.played_character)
	FROM item_pickups a
	LEFT JOIN played_characters b
	ON a.played_character = b.id
	WHERE item_name = 'MomsKnife'
	AND b.died_from IS NOT NULL

	--Frequency of Mom's Knife showing up on a certain floor
	SELECT floor, COUNT(item_name)
	FROM item_pickups
	WHERE item_name = 'MomsKnife'
	GROUP BY floor
	ORDER BY COUNT(item_name) DESC

	--Number of time rerolled into Mom's Knife
	SELECT COUNT(item_name)
	FROM item_pickups
	WHERE item_name = 'MomsKnife'
	AND was_rerolled = True

	--Times transformed
	SELECT COUNT(resource_one)
	FROM gameplay_events
	WHERE event_type = 11

	--Times transformed by transformation
	SELECT resource_two, COUNT(resource_two)
	FROM gameplay_events
	WHERE event_type = 11
	GROUP BY resource_two
	ORDER BY COUNT(resource_two) DESC

	--Total number of items collected per floor
	SELECT b.floor, COUNT(a.item_name) AS item_count, c.floor_order
	FROM item_pickups a
	LEFT JOIN played_floors b
	ON a.played_floor = b.id
	LEFT JOIN standard_floors c
	ON b.floor = c.floor
	GROUP BY b.floor, c.floor_order
	ORDER BY c.floor_order

	--Total number of times fighting each boss
	SELECT resource_one, COUNT(resource_one)
	FROM gameplay_events
	WHERE event_type = 4
	GROUP BY resource_one
	ORDER BY COUNT(resource_one) DESC