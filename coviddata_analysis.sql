-- Initial Data Selection
SELECT *
FROM public.covid_deaths
WHERE continent IS NOT NULL 
ORDER BY 3, 4;

-- Selecting Data for Exploration
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM public.covid_deaths
WHERE continent IS NOT NULL 
ORDER BY 1, 2;

-- Total Cases vs Total Deaths: Likelihood of dying if contracting COVID
SELECT location, date, total_cases, total_deaths, 
       (total_deaths / NULLIF(total_cases, 0)) * 100 AS death_percentage
FROM public.covid_deaths
WHERE location ILIKE '%states%' 
  AND continent IS NOT NULL 
ORDER BY 1, 2;

-- Total Cases vs Population: Percentage of population infected
SELECT location, date, population, total_cases,  
       (total_cases / NULLIF(population, 0)) * 100 AS percent_population_infected
FROM public.covid_deaths
ORDER BY 1, 2;

-- Countries with Highest Infection Rate Compared to Population
SELECT location, population, 
       MAX(total_cases) AS highest_infection_count,  
       MAX(total_cases / NULLIF(population, 0)) * 100 AS percent_population_infected
FROM public.covid_deaths
GROUP BY location, population
ORDER BY percent_population_infected DESC;

-- Countries with Highest Death Count per Population
SELECT location, 
       MAX(CAST(total_deaths AS INTEGER)) AS total_death_count
FROM public.covid_deaths
WHERE continent IS NOT NULL 
GROUP BY location
ORDER BY total_death_count DESC;

-- Continent Breakdown: Continent with Highest Death Count per Population
SELECT continent, 
       MAX(CAST(total_deaths AS INTEGER)) AS total_death_count
FROM public.covid_deaths
WHERE continent IS NOT NULL 
GROUP BY continent
ORDER BY total_death_count DESC;

-- Global Numbers: Summing cases, deaths, and calculating global death percentage
SELECT SUM(new_cases) AS total_cases, 
       SUM(CAST(new_deaths AS INTEGER)) AS total_deaths, 
       (SUM(CAST(new_deaths AS INTEGER)) / NULLIF(SUM(new_cases), 0)) * 100 AS death_percentage
FROM public.covid_deaths
WHERE continent IS NOT NULL;

-- Total Population vs Vaccinations: Percentage of population vaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
       SUM(CAST(NULLIF(vac.new_vaccinations, '') AS INTEGER)) 
       OVER (PARTITION BY dea.location ORDER BY dea.date) AS rolling_people_vaccinated
FROM public.covid_deaths dea
JOIN public.covid_vaccinations vac
  ON dea.location = vac.location 
  AND dea.date = CAST(vac.date AS DATE)  -- Cast vac.date to DATE type
WHERE dea.continent IS NOT NULL 
ORDER BY 2, 3;



-- CTE for Calculating Population Vaccination Percentage
WITH PopvsVac AS (
    SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
           SUM(CAST(NULLIF(vac.new_vaccinations, '') AS INTEGER)) 
           OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
    FROM public."covid_deaths" dea
    JOIN public."covid_vaccinations" vac
        ON dea.location = vac.location
        AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT *, (RollingPeopleVaccinated / population) * 100 AS VaccinationPercentage
FROM PopvsVac;


-- Temporary Table for Population Vaccination Percentage
DROP TABLE IF EXISTS percent_population_vaccinated;

CREATE TEMP TABLE percent_population_vaccinated (
    continent VARCHAR(255),
    location VARCHAR(255),
    date DATE,
    population NUMERIC,
    new_vaccinations NUMERIC,
    rolling_people_vaccinated NUMERIC
);

INSERT INTO percent_population_vaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, 
       CASE 
           WHEN vac.new_vaccinations = '' THEN NULL
           ELSE CAST(vac.new_vaccinations AS NUMERIC)
       END AS new_vaccinations,
       SUM(CAST(
           CASE 
               WHEN vac.new_vaccinations = '' THEN NULL
               ELSE vac.new_vaccinations
           END AS NUMERIC)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS rolling_people_vaccinated
FROM public.covid_deaths dea
JOIN public.covid_vaccinations vac
  ON dea.location = vac.location AND dea.date = vac.date;

SELECT *, 
       (rolling_people_vaccinated / NULLIF(population, 0)) * 100 AS percent_population_vaccinated
FROM percent_population_vaccinated;

-- Creating a View for Population Vaccination Data
CREATE OR REPLACE VIEW percent_population_vaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, 
       CASE 
           WHEN vac.new_vaccinations = '' THEN NULL
           ELSE CAST(vac.new_vaccinations AS NUMERIC)
       END AS new_vaccinations,
       SUM(CAST(
           CASE 
               WHEN vac.new_vaccinations = '' THEN NULL
               ELSE vac.new_vaccinations
           END AS NUMERIC)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS rolling_people_vaccinated
FROM public.covid_deaths dea
JOIN public.covid_vaccinations vac
  ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

