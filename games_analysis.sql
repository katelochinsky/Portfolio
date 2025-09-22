/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Екатерина Лощинская
 * Дата: 18.11.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
SELECT
	COUNT (id) AS total_users, --общее количество игроков, зарегистрированных в игре
	SUM(payer) AS total_payers, --количество платящих игроков
	ROUND(AVG(payer),4) AS payers_percentage --доля платящих игроков от общего количества пользователей
FROM fantasy.users
WHERE payer=1 OR payer=0; --правка по ревью
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
	race.race, -- раса персонажа
	SUM(users.payer) AS total_payers,-- количество платящих игроков
	COUNT (users.id) AS total_users,-- общее количество зарегистрированных игроков
	ROUND((SUM(users.payer)::numeric/COUNT (users.id)::numeric),4) AS payers_percentage-- доля платящих игроков от общего количества пользователей
FROM fantasy.users 
JOIN fantasy.race USING(race_id)
GROUP BY race.race
ORDER BY total_payers DESC; --правка по ревью
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
WITH cte AS (
SELECT 
	transaction_id,
	amount AS amount_no_zeroes
FROM fantasy.events
WHERE amount IS NOT NULL AND amount>0
GROUP BY transaction_id)
	SELECT 
		COUNT (events.transaction_id) AS total_purchase_count, -- общее количество покупок
		SUM (amount) AS sum_amount, -- суммарная стоимость всех покупок
		MIN (events.amount)::NUMERIC(10, 2) AS min_amount, --правка по ревью - округление
		MIN(cte.amount_no_zeroes)::NUMERIC(10, 2) AS min_amount_no_zeroes, -- правка по ревью, минимум без 0 покупок
		MAX(amount)::NUMERIC(10, 2) AS max_amount,
		AVG(amount)::NUMERIC(10, 2) AS avg_amount,
		PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY amount) AS median,
		STDDEV(amount)::NUMERIC(10, 2) AS stand_dev
FROM fantasy.events
LEFT JOIN cte ON events.transaction_id=cte.transaction_id
WHERE amount IS NOT NULL;
-- 2.2: Аномальные нулевые покупки
WITH zero AS (
	SELECT 
		COUNT(*) AS zero_purchase_count --количество нулевых покупок
	FROM fantasy.events
	WHERE amount=0
	),
total AS (
	SELECT 
		COUNT(transaction_id) AS total_purchase_count 
	FROM fantasy.events)
SELECT 
	zero_purchase_count, 
	total_purchase_count, -- общее количество покупок
	ROUND((zero_purchase_count::NUMERIC/total_purchase_count::NUMERIC),4)  AS zero_amount_share-- доля нулевых покупок
FROM zero, total;
--Правка по ревью
SELECT 
COUNT(transaction_id) FILTER (WHERE amount = 0), 
COUNT(transaction_id),
ROUND (((COUNT(transaction_id) FILTER (WHERE amount = 0))::NUMERIC/COUNT(transaction_id)::NUMERIC),4)
FROM fantasy.events;
-- Правка по ревью. Какие эпические предметы купили за нулевую стоимость:
SELECT COUNT (events.transaction_id) AS zero_purchase_count, --количество нулевых покупок
 		items.game_items AS item_name --название эпического предмета
FROM fantasy.events
JOIN fantasy.items ON events.item_code=items.item_code
WHERE amount = 0
GROUP BY items.game_items; 
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
/*SELECT 
	CASE WHEN users.payer=0
	THEN 'nonpayers' --неплатящие игроки
	ELSE 'payers' --платящие игроки
	END category,
	COUNT (DISTINCT users.id) AS users_count,	-- общее количество игроков
	ROUND((COUNT(transaction_id)::NUMERIC/COUNT (DISTINCT users.id))) AS avg_purchase_per_user, --среднее количество покупок
	ROUND(SUM(events.amount)::NUMERIC/COUNT (DISTINCT users.id),2) AS avg_amount_per_user --средняя суммарная стоимость на игрока
FROM fantasy.users
JOIN fantasy.events USING(id)
WHERE events.transaction_id NOT IN (SELECT transaction_id 
			FROM fantasy.events 
			WHERE amount=0)
GROUP BY users.payer; */
--Правка по ревью. Оптимизация запроса
WITH cte AS (
SELECT users.id AS user_id,
		users.payer AS payer,
		COUNT (events.transaction_id) AS purchase_count,
		SUM (events.amount) AS sum_amount
FROM fantasy.events
LEFT JOIN fantasy.users ON events.id=users.id
WHERE events.amount!=0
GROUP BY users.id, users.payer)
SELECT 
	CASE WHEN payer=0
		THEN 'nonpayers' --неплатящие игроки
		ELSE 'payers' --платящие игроки
		END category,
	COUNT (user_id) AS users_count,
	AVG(purchase_count)::NUMERIC(10, 0) AS avg_purchase_per_user,
	AVG(sum_amount)::NUMERIC(10, 2) AS avg_amount_per_user
FROM cte
GROUP BY payer;
--Статистика по платящим и неплатящим игрокам в разрезе расы:
WITH cte AS (
SELECT users.id AS user_id,
		users.payer AS payer,
		race.race AS race,
		COUNT (events.transaction_id) AS purchase_count,
		SUM (events.amount) AS sum_amount
FROM fantasy.events
LEFT JOIN fantasy.users ON events.id=users.id
LEFT JOIN fantasy.race ON users.race_id=race.race_id
WHERE events.amount!=0
GROUP BY users.id, users.payer, race.race)
SELECT 
	CASE WHEN payer=0
		THEN 'nonpayers' --неплатящие игроки
		ELSE 'payers' --платящие игроки
		END category,
	race,
	COUNT (user_id) AS users_count,
	AVG(purchase_count)::NUMERIC(10, 0) AS avg_purchase_per_user,
	AVG(sum_amount)::NUMERIC(10, 2) AS avg_amount_per_user
FROM cte
GROUP BY payer, race
ORDER BY race, payer;
-- 2.4: Популярные эпические предметы:
SELECT  
		i.game_items AS item_name,
		COUNT(e.transaction_id) AS item_count,--общее количество внутриигровых продаж для каждого предмета
		ROUND((COUNT(e.transaction_id)::NUMERIC)/(SELECT 
														COUNT(transaction_id)
												FROM fantasy.events 
												WHERE amount>0),6) AS item_purchase_share, --доля продажи каждого предмета от всех продаж
		ROUND((COUNT(DISTINCT e.id)::NUMERIC)/(SELECT 
														COUNT(DISTINCT id)
												FROM fantasy.events 
												WHERE amount>0),6) AS buyers_share --доля игроков, которые покупали предмет									
FROM fantasy.events e 
JOIN fantasy.items i USING(item_code)
WHERE e.transaction_id NOT IN (SELECT transaction_id FROM fantasy.events WHERE amount=0)
GROUP BY item_name
ORDER BY item_count DESC;
--Правка по ревью. Эпические предметы, которые не купили ни разу:
SELECT game_items, --название предмета
		COUNT (game_items) OVER() -- общее количество всех предметов
FROM fantasy.items
WHERE game_items NOT IN (SELECT items.game_items AS item_name									
							FROM fantasy.events 
							JOIN fantasy.items USING(item_code));
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH cte1 AS (
		SELECT 
			race.race AS race, 
		COUNT (users.id) AS total_users --общее количество зарегистрированных игроков
		FROM fantasy.users 
		JOIN fantasy.race USING(race_id)
		GROUP BY race.race),
cte2 AS (
		SELECT r.race AS race,
			COUNT (DISTINCT e.id) AS total_buyers, --количество игроков, совершивших покупку
			COUNT(DISTINCT e.id) FILTER (WHERE u.payer = 1) AS total_payers --количество платящих игроков
		FROM fantasy.events e
		JOIN fantasy.users u USING (id)
		JOIN fantasy.race r USING(race_id)
		WHERE e.amount > 0
		GROUP BY r.race
),
cte3 AS (SELECT DISTINCT (e.id) AS buyer,
	r.race AS race, 
	COUNT(e.transaction_id) AS purchase_count,
	SUM(e.amount) AS sum_amount,
	SUM(e.amount)::numeric AS avg_amount_per_purchase
FROM fantasy.events e
JOIN fantasy.users u USING (id)
JOIN fantasy.race r USING(race_id)
WHERE e.amount > 0 
GROUP BY DISTINCT (e.id), r.race)
SELECT 	cte1.race,
		cte1.total_users, --общее количество зарегистрированных игроков
		cte2.total_buyers,--количество игроков, совершивших покупку,
		ROUND((cte2.total_buyers::numeric/cte1.total_users::NUMERIC),4) AS buyers_share, --доля совершивших покупки от общего количества
		cte2.total_payers,
		ROUND((cte2.total_payers::NUMERIC/cte2.total_buyers::NUMERIC),4) AS payers_share, --доля платящих игроков от количества игроков, которые совершили покупки
		ROUND(AVG(purchase_count),2) AS avg_purchase_count, --среднее количество покупок на одного игрока
		ROUND((AVG(cte3.avg_amount_per_purchase::NUMERIC)/AVG(purchase_count)),2) AS avg_amount_per_purchase, --средняя стоимость одной покупки
		ROUND((AVG(sum_amount))::numeric,2) AS avg_sum_amount --средняя суммарная стоимость всех покупок на одного игрока
FROM cte1
INNER JOIN cte2 ON cte1.race=cte2.race
INNER JOIN cte3 ON cte2.race=cte3.race
GROUP BY cte1.race, cte1.total_users,cte2.total_buyers,cte2.total_payers
ORDER BY cte1.total_users desc;
-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь


