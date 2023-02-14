## NORTHERNLION DATABASE SQL QUERIES

This is a collection of SQL queries to examine the data stored in the [Northernlion Database](https://northernlion-db.com/)

### BACKGROUND
This database contains data about the Youtube videos of Northernlion (NL) and his long-running series of videos on the Binding of Isaac video game.
Fans of the series catalogued as much data as they could from these videos. This includes data from the Youtube API like views and likes, but also much more, including the specific game events that happened in each video and the conversation topics from each video.

I am fan of the videos and the game and was excited to explore the data as a way to practice using SQL to ask and answers questions using data.

[This page](https://northernlion-db.com/SqlDump/Tables) has more information on the tables included in this database as well as incstructions for downloading the databse itself.

### ORGANIZATION
The SQL script is organized with the highlights at the top of the file. These are the questions that required the most complex SQL queries and yielded some more interesting results.
After that, I have included some queries on the less serious side, followed by all of the queries I wrote as part of this exercise. 

### PROCESS
I started by looking at the information contained in each table for inspiration. I then made a list of questions that this particular table could answer.
For example, starting with the `videos` table, I could answer questions like 'which video has the most views? The most likes?' (It's the first one, btw).
I could also see stats like the total time spent on playing the game in videos (~3,200 hours). Interesting, but pretty straightforward. Moving on to other tables got more interesting.
With these I could determine which enemy was the deadliest and ended the most runs, what NL's favorite character was, overall win percentage, total number of times taking a certain item, how an item relates to the chance to win a run, etc.
This led to a lot of exploring and gave me plenty of opportunities to flex some SQL skills with Joins, Subqueries, CTEs, Window Functions and more. 
There were also multiple ways to solve a question. For example, using the `gameplay_events` table to find where runs were won or lost, or using the `played_characters` table and the `died_from` column to determine a loss.

### TAKEAWAY
This database was really fun to work with. I able to use some of my own knowledge of the game and the series to inform my exploration of the data, while at the same time exploring how to navigate a database that is designed to contain a lot of varying types of information. 
It was a helpful exercise in learning the importance of primary keys and normalizing data. Prior to working with this data, I would have had no idea how to catalogue every action taken in the game into a databse, let alone a single table, but I'm happy to have found an answer. 
This has also got me excited to explore datasets from other games and the insights they might yield. As a hobbyist game developer, it's exciting to potentially have data-driven answers to questions like 'which item is the most popular?' or 'is this item actually overpowered?'

### NEXT STEPS
The data found from this exercise will be visualized on Tableau Public.

