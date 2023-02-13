--VIEWS FOR TABLEAU
	-- Relevant Video Stats (1-6)
		CREATE VIEW nldb_video_stats AS
		SELECT title, DATE(published), view_count, likes, duration/60 AS length_min
		FROM videos

--VIZ THIS
	-- VIDEO STATS
		--1. Most viewed video
		SELECT title, DATE(published), view_count
		FROM videos
		WHERE view_count = (SELECT MAX(view_count) FROM videos)

		--2. Most liked video (Same as above)
		SELECT title, DATE(published), likes
		FROM videos
		WHERE likes = (SELECT MAX(likes) FROM videos)	

		--3. Views per video
		SELECT title, DATE(published), view_count
		FROM videos
		ORDER BY DATE(published) ASC

		--4. Average views per video
		SELECT TRUNC(AVG(view_count),0) AS avg_views
		FROM videos

		--5. Average video length	
		SELECT AVG(duration)/60 AS minutes
		FROM videos

		--6. Total hours played
		SELECT SUM(duration)/360 AS hours_played
		FROM videos

	-- GAMEPLAY STATS
		--7. Deadliest enemies
		SELECT died_from, COUNT(died_from)
		FROM played_characters
		WHERE died_from IS NOT null
		AND latest = true
		GROUP BY died_from
		ORDER BY COUNT(died_from) DESC
		
		--8. Runs by character
		SELECT game_character, COUNT(game_character)
		FROM played_characters
		WHERE latest = true
		GROUP BY game_character
		ORDER BY COUNT (game_character) DESC
		
		--9. Total runs, wins, deaths by character, excluding forced resets and exiting game
		-- Drop temp table if it already exists
		DROP TABLE IF EXISTS death_table

		-- Create a temp table to group all runs that resulted in a death
		SELECT game_character, COUNT(run_number) as deaths
		INTO TEMP death_table
		FROM played_characters
		WHERE died_from IS NOT NULL
		AND died_from != 'ForcedReset'
		AND died_from != 'ExitedGame'
		AND latest = true
		GROUP BY game_character
		ORDER BY COUNT(run_number) DESC

		-- Use CTE to get all winning and losing runs (excluding Forced Resets and Exited Game) grouped by character
		WITH runs_by_char (game_character, total_runs)
		AS
		(
			SELECT game_character, COUNT(run_number) AS total_runs
			FROM (
				--winning runs
				SELECT game_character, run_number
				FROM played_characters
				WHERE latest = true
				AND died_from IS NULL
				UNION ALL
				-- losing runs, excluding FR and EG
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
	
		--10. Number of episodes with multiple wins in the same video
		SELECT COUNT(*) AS multi_win_videos 
		FROM (
			SELECT submission, COUNT(run_number)
			FROM played_characters
			WHERE died_from IS NULL
			AND latest = true
			GROUP BY submission
			HAVING COUNT(run_number) > 1
		) multi_wins


		--11. number of episodes with multiple losses in the same video
		SELECT COUNT(*) AS multi_loss_videos 
		FROM (
			SELECT submission, COUNT(run_number)
			FROM played_characters
			WHERE died_from IS NOT NULL
			AND latest = true
			GROUP BY submission
			HAVING COUNT(run_number) > 1
		) multi_losses

		--12. Number of episodes with multiple losses, exluding FR and exiting the game
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

		--13. Number of force rests by character
		SELECT game_character, COUNT(run_number) as forced_resets
		FROM played_characters
		WHERE died_from = 'ForcedReset'
		AND latest = true
		GROUP BY game_character
		ORDER BY COUNT(run_number) DESC

		--14. Total deaths by character, excluding forced resets and exiting game
		SELECT game_character, COUNT(run_number) as deaths
		FROM played_characters
		WHERE died_from IS NOT NULL
		AND died_from != 'ForcedReset'
		AND died_from != 'ExitedGame'
		AND latest = true
		GROUP BY game_character
		ORDER BY COUNT(run_number) DESC


		--15. Total number of runs, total number of wins, total number of deaths excluding forced resets and exiting game
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

		--16. Last floor for each winning run
			DROP TABLE IF EXISTS last_floors
				
			-- Create Temp table containing ending floor_number for each run
			SELECT MAX(id) AS id, played_character AS run_number, MAX(floor_number) AS floor_number
			INTO TEMP last_floors
			FROM played_floors
			WHERE latest = true
			GROUP BY played_character
			ORDER BY  played_character
			
			-- Select with Join to add name of floor for each run
			SELECT b.run_number, a.floor, b.floor_number
			FROM played_floors a
			RIGHT JOIN last_floors b
			ON a.id = b.id
			WHERE a.died_from IS NULL

			--Count of wins for each floor
			SELECT a.floor, COUNT(*) AS total_wins
			FROM played_floors a
			RIGHT JOIN last_floors b
			ON a.id = b.id
			WHERE died_from IS NULL
			GROUP BY a.floor
			ORDER BY total_wins DESC
		
		--Last floor of each run, whether it was a win or a loss, a running total of number of wins win percentage
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

		
		--Total encounters of each floor
			SELECT floor, COUNT(floor) AS number
			FROM played_floors
			GROUP BY floor
			ORDER BY COUNT(floor) DESC











--EXPLORING

select *
from gameplay_events
	
	--Percentage of winning runs with Mom's Knife
	--Frequency of Mom's Knife per floor
	--Average number of items collected per floor
			
			
			
			

			-- Use CASE to count winning or losing runs based on died_from
			
			SELECT * , 	CASE
							WHEN died_from IS NULL THEN 1
							WHEN died_from IS NOT NULL THEN 0
							END win-- OVER (PARTITION BY id)
			FROM played_characters
			
			SELECT * --LAST_VALUE(a.floor) OVER (PARTITION BY a.played_character)
			FROM played_floors a
			JOIN played_characters b
			ON a.played_character = b.id
			WHERE b.died_from IS NULL
			AND a.latest = true
			GROUP BY played_character
			HAVING a.id = LAST_VALUE(a.id) OVER (PARTITION BY a.floor)


			SELECT *
			FROM played_characters
			
			
		
			
			
			-- WIP. Want to display floor name, the number of wins on that floor, and the percentage of wins on that floor compared to total wins
			--Maybe join with played_characters instead to determine winning runs, then count from there
			WITH total_winning_runs
			AS
				(
				--Count of wins for each floor
				SELECT COUNT(*) AS total_wins
				FROM played_floors a
				RIGHT JOIN last_floors b
				ON a.id = b.id
				WHERE died_from IS NULL
				)
			SELECT a.floor, total_wins
			FROM played_floors a
			RIGHT JOIN last_floors b
			ON a.id = b.id
			WHERE died_from IS NULL
			GROUP BY a.floor
			ORDER BY total_wins DESC
	
	
	--Count of wins for each floor
				SELECT a.floor, COUNT(*) AS total_wins
				FROM played_floors a
				RIGHT JOIN last_floors b
				ON a.id = b.id
				WHERE died_from IS NULL
				GROUP BY a.floor
				ORDER BY total_wins DESC
			
	SELECT *
	FROM videos
	ORDER BY DATE(published) ASC

	SELECT title, published, likes, dislikes, view_count, comment_count 
	FROM videos
	ORDER BY view_count DESC

	Select *
	FROM played_characters
	WHERE video = 'DRXY0J2V0f8'

	-- Unable to calculate
	-- Database adds all causes of death as an 'Enemy', despite the existence of the resource in the DB as a different type
	-- eg, both Monstro (type: 1, Boss) and MonstroEnemy (type: 11, Enemy) exist, despite referring to the same in-game entity
	-- Similarly, MrMega (type: 6, Item) and MrMegaEnemy (type: 11, Enemy) also exist
	-- rather than played_characters.died_from referring directly to the boss or item, a new entry is made with the suffix 'Enemy' and type 11
	-- As such, all deaths are attributed to 'Enemies'. Not sure why this limitation is used.
	-- Would not be able to determine ids with suffix 'Enemy' as item, or boss, or other, without making an exhaustive list of each category for comparison
-- 		--Deaths per enemy type
-- 		SELECT b.type, COUNT(a.died_from)
-- 		FROM played_characters a
-- 		LEFT JOIN isaac_resources b
-- 		ON a.died_from = b.id
-- 		WHERE a.died_from IS NOT NULL
-- 		GROUP BY b.type



	-- Percentage of runs for each path (Chest, Sheol, Dark Room)
	-- Find MAX floor number per run to determine where run ended?
	-- Number of winning runs that ended at each floor

				
		
		
	-- Ending floor_number for each run
	SELECT MAX(id) AS id, played_character AS run_number, MAX(floor_number)
	FROM played_floors
	WHERE latest = true
	GROUP BY played_character
 	ORDER BY  played_character







	
	SELECT *
	FROM played_floors
	WHERE played_character = 35858
		

-- frequency percentage of each floor as a total of all floors

		
--Examples from website
select videos.title, played_characters.game_character, played_characters.died_from
from played_characters
join videos on videos.id = played_characters.video
where played_characters.died_from = 'BombedHimself'
and played_characters.latest = true
order by videos.published desc; 

select videos.title, played_characters.game_character, played_characters.died_from
from played_characters
join videos on videos.id = played_characters.video
where played_characters.died_from is not null
and played_characters.latest = true
and extract(DOW from videos.published) = 5; 
