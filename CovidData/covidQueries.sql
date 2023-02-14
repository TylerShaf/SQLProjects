/*
Covid 19 Data Exploration 
Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types
*/


Select *
From PortfolioProject..CovidDeaths
Where continent is not null 
order by date

-- Select subset of data that I will focus on
Select Location, date, total_cases, new_cases, new_deaths, total_deaths, population
From PortfolioProject..CovidDeaths
Where continent is not null --This statement excludes some data that aggregates some countries together by category such as "Asia" or "Middle Income", ensuring each country's data is only counted once.
order by location



-- COUNTRY BREAKDOWN
-- Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid in your country over time
Select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From PortfolioProject..CovidDeaths
Where location like '%states'
and continent is not null 
order by 1,2


-- Total Cases vs Population
-- Shows percentage of population infected with Covid over time by country
Select Location, date, Population, total_cases,  (total_cases/population)*100 as PercentPopulationInfected
From PortfolioProject..CovidDeaths
Where continent is not null 
order by 1,2


-- Countries with Highest Infection Rate compared to Population
Select Location, Population, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From PortfolioProject..CovidDeaths
Group by Location, Population
order by PercentPopulationInfected desc


-- Countries with Highest Death Count compared to Population
Select Location, MAX(population) as Population, MAX(cast(Total_deaths as int)) as TotalDeathCount
, (MAX(cast(Total_deaths as int))/population)*100 as DeathPercentage
From PortfolioProject..CovidDeaths
Where continent is not null 
Group by Location, population
order by TotalDeathCount desc



--CONTINENT BREAKDOWN
-- Showing contintents with the highest death count
Select continent, SUM(cast(new_deaths as int)) as TotalDeathCount
From PortfolioProject..CovidDeaths
Where continent is not null 
Group by continent
order by TotalDeathCount desc



-- GLOBAL NUMBERS
-- Shows total number of cases and deaths globally
Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From PortfolioProject..CovidDeaths
where continent is not null 
order by 1,2


--Shows new cases/deaths on each day as well as running totals over time.
SELECT date, SUM(new_cases) as GlobalDailyCases, SUM(total_cases) as GlobalTotalCases, SUM(cast(new_deaths as int)) as GlobalDailyDeaths, SUM(cast(total_deaths as int)) AS GlobalTotalDeaths
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY date


--Daily and Total global cases for a specific day
Select date, 
SUM(new_cases) AS NewDailyCases, 
SUM(total_cases) AS TotalCases
From PortfolioProject..CovidDeaths
Where date = '2020-11-06 00:00:00.000'
AND continent is not null 
GROUP BY date
order by date



-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine by country over time.
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVax vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
order by location, date


-- Using CTE to perform Calculation on Partition By in previous query
With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVax vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
)
Select *, (RollingPeopleVaccinated/Population)*100 as PercentVaccinated
From PopvsVac


-- Using Temp Table to perform Calculation on Partition By in previous query
DROP Table if exists #PercentPopulationVaccinated --Added to replace existing table if alterations need to be made
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVax vac
	On dea.location = vac.location
	and dea.date = vac.date
--where dea.continent is not null 
order by location, date

Select *, (RollingPeopleVaccinated/Population)*100 as PercentVaccinated
From #PercentPopulationVaccinated




-- Creating View to store data for later visualizations

Create View PercentPopVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVax vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 


CREATE VIEW GlobalRunningTotals as
SELECT date, SUM(new_cases) as GlobalDailyCases, SUM(total_cases) as GlobalTotalCases, SUM(cast(new_deaths as int)) as GlobalDailyDeaths, SUM(cast(total_deaths as int)) AS GlobalTotalDeaths
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
